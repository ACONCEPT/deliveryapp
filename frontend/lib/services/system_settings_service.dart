import 'dart:convert';
import 'dart:developer' as developer;
import '../models/system_setting.dart';
import 'base_service.dart';

/// Service for managing system settings via admin API
///
/// Provides methods for fetching, updating, and managing system-wide configuration settings.
/// All methods require admin JWT token authentication.
class SystemSettingsService extends BaseService {
  @override
  String get serviceName => 'SystemSettingsService';

  /// Get all system settings, optionally filtered by category
  ///
  /// [token] - Admin JWT bearer token
  /// [category] - Optional category filter (e.g., 'orders', 'payments')
  ///
  /// Returns [SettingsResponse] with settings grouped by category
  Future<SettingsResponse> getSettings(
    String token, {
    String? category,
  }) async {
    try {
      developer.log(
        'Fetching system settings${category != null ? " for category: $category" : ""}',
        name: serviceName,
      );

      final queryParams = category != null ? '?category=$category' : '';
      final response = await httpClient.get(
        '/api/admin/settings$queryParams',
        headers: authHeaders(token),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        final settingsResponse = SettingsResponse.fromJson(responseData);

        developer.log(
          '✅ Successfully fetched ${settingsResponse.totalCount} settings '
          'across ${settingsResponse.categoriesCount} categories',
          name: serviceName,
        );

        return settingsResponse;
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(errorData['message'] ?? 'Failed to fetch settings');
      }
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error fetching settings: $e',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get all available setting categories
  ///
  /// [token] - Admin JWT bearer token
  ///
  /// Returns [CategoriesResponse] with list of category names
  Future<CategoriesResponse> getCategories(String token) async {
    try {
      developer.log('Fetching setting categories', name: serviceName);

      final response = await httpClient.get(
        '/api/admin/settings/categories',
        headers: authHeaders(token),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        final categoriesResponse = CategoriesResponse.fromJson(responseData);

        developer.log(
          '✅ Successfully fetched ${categoriesResponse.count} categories',
          name: serviceName,
        );

        return categoriesResponse;
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(errorData['message'] ?? 'Failed to fetch categories');
      }
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error fetching categories: $e',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get a single setting by key
  ///
  /// [token] - Admin JWT bearer token
  /// [key] - Setting key (e.g., 'tax_rate', 'minimum_order_amount')
  ///
  /// Returns [SingleSettingResponse] with the setting
  Future<SingleSettingResponse> getSetting(String token, String key) async {
    try {
      developer.log('Fetching setting: $key', name: serviceName);

      final response = await httpClient.get(
        '/api/admin/settings/$key',
        headers: authHeaders(token),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        final settingResponse = createSingleSettingResponse(responseData);

        developer.log(
          '✅ Successfully fetched setting: $key = ${settingResponse.data?.settingValue ?? "null"}',
          name: serviceName,
        );

        return settingResponse;
      } else if (response.statusCode == 404) {
        throw Exception('Setting not found: $key');
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(errorData['message'] ?? 'Failed to fetch setting');
      }
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error fetching setting $key: $e',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update a single setting by key
  ///
  /// [token] - Admin JWT bearer token
  /// [key] - Setting key to update
  /// [value] - New value (as string, will be validated by backend based on data_type)
  ///
  /// Returns updated [SingleSettingResponse]
  Future<SingleSettingResponse> updateSetting(
    String token,
    String key,
    String value,
  ) async {
    try {
      developer.log(
        'Updating setting: $key = $value',
        name: serviceName,
      );

      final request = UpdateSettingRequest(value: value);
      final response = await httpClient.put(
        '/api/admin/settings/$key',
        headers: authHeaders(token),
        body: request.toJson(),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        final settingResponse = createSingleSettingResponse(responseData);

        developer.log(
          '✅ Successfully updated setting: $key',
          name: serviceName,
        );

        return settingResponse;
      } else if (response.statusCode == 400) {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(
          errorData['message'] ?? 'Validation error or read-only setting',
        );
      } else if (response.statusCode == 404) {
        throw Exception('Setting not found: $key');
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(errorData['message'] ?? 'Failed to update setting');
      }
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error updating setting $key: $e',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update multiple settings in a single transaction
  ///
  /// [token] - Admin JWT bearer token
  /// [updates] - Map of setting keys to new values
  ///
  /// Returns [BatchUpdateResponse] with success/failure details
  ///
  /// Example:
  /// ```dart
  /// final result = await service.batchUpdateSettings(
  ///   token,
  ///   {
  ///     'tax_rate': '0.09',
  ///     'minimum_order_amount': '15.00',
  ///     'default_delivery_fee': '6.99',
  ///   },
  /// );
  /// ```
  Future<BatchUpdateResponse> batchUpdateSettings(
    String token,
    Map<String, String> updates,
  ) async {
    try {
      developer.log(
        'Batch updating ${updates.length} settings',
        name: serviceName,
      );

      final settingRequests = updates.entries
          .map((e) => BatchUpdateSettingRequest(key: e.key, value: e.value))
          .toList();

      final request = UpdateMultipleSettingsRequest(settings: settingRequests);
      final response = await httpClient.put(
        '/api/admin/settings',
        headers: authHeaders(token),
        body: request.toJson(),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        final batchResponse = createBatchUpdateResponse(responseData);

        final result = batchResponse.data;
        if (result != null) {
          developer.log(
            '✅ Batch update completed: ${result.successCount} succeeded, '
            '${result.failureCount} failed',
            name: serviceName,
          );

          if (result.hasErrors) {
            developer.log(
              '⚠️  Batch update errors:',
              name: serviceName,
            );
            for (final error in result.errors) {
              developer.log(
                '   - ${error.key}: ${error.message}',
                name: serviceName,
              );
            }
          }
        }

        return batchResponse;
      } else if (response.statusCode == 400) {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(
          errorData['message'] ?? 'Validation error in batch update',
        );
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(
          errorData['message'] ?? 'Failed to batch update settings',
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error in batch update: $e',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Validate setting value based on data type
  ///
  /// Returns true if valid, false otherwise
  /// This is a client-side validation helper
  bool validateSettingValue(String value, SettingDataType dataType) {
    switch (dataType) {
      case SettingDataType.number:
        return double.tryParse(value) != null;
      case SettingDataType.boolean:
        return value.toLowerCase() == 'true' || value.toLowerCase() == 'false';
      case SettingDataType.json:
        try {
          json.decode(value);
          return true;
        } catch (e) {
          return false;
        }
      case SettingDataType.string:
        return value.isNotEmpty;
    }
  }

  /// Get validation error message for invalid value
  ///
  /// Returns null if valid, error message if invalid
  String? getValidationError(String value, SettingDataType dataType) {
    switch (dataType) {
      case SettingDataType.number:
        if (double.tryParse(value) == null) {
          return 'Must be a valid number';
        }
        return null;
      case SettingDataType.boolean:
        if (value.toLowerCase() != 'true' && value.toLowerCase() != 'false') {
          return 'Must be "true" or "false"';
        }
        return null;
      case SettingDataType.json:
        try {
          json.decode(value);
          return null;
        } catch (e) {
          return 'Must be valid JSON';
        }
      case SettingDataType.string:
        if (value.isEmpty) {
          return 'Cannot be empty';
        }
        return null;
    }
  }

  /// Convert typed value to string for API submission
  ///
  /// Handles conversion from Dart types to string format expected by API
  static String valueToString(dynamic value, SettingDataType dataType) {
    switch (dataType) {
      case SettingDataType.number:
        if (value is num) {
          return value.toString();
        }
        return value.toString();
      case SettingDataType.boolean:
        if (value is bool) {
          return value.toString();
        }
        return value.toString();
      case SettingDataType.json:
        if (value is String) {
          return value;
        }
        return json.encode(value);
      case SettingDataType.string:
        return value.toString();
    }
  }
}
