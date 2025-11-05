import 'dart:convert';
import 'dart:developer' as developer;
import '../models/restaurant.dart';
import '../models/restaurant_request.dart';
import '../models/vendor_settings.dart';
import 'base_service.dart';

class RestaurantService extends BaseService {
  @override
  String get serviceName => 'RestaurantService';

  // Get all restaurants
  Future<List<Restaurant>> getRestaurants(String token) {
    return getList(
      '/api/restaurants',
      'restaurants',
      Restaurant.fromJson,
      token: token,
    );
  }

  // Get a specific restaurant by ID
  Future<Restaurant> getRestaurant(String token, int id) {
    return getObject(
      '/api/restaurants/$id',
      'restaurant',
      Restaurant.fromJson,
      token: token,
    );
  }

  // Get restaurant owner information
  Future<Map<String, dynamic>> getRestaurantOwner(String token, int restaurantId) async {
    try {
      final response = await httpClient.get(
        '/api/restaurants/$restaurantId/owner',
        headers: authHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        developer.log('Parsed JSON: $data', name: serviceName);
        return data as Map<String, dynamic>;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load restaurant owner');
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error in getRestaurantOwner',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // Create a new restaurant (vendor endpoint)
  Future<Restaurant> createRestaurant(String token, CreateRestaurantRequest request) {
    return postObject(
      '/api/vendor/restaurants',
      'restaurant',
      request.toJson(),
      Restaurant.fromJson,
      token: token,
    );
  }

  // Update an existing restaurant (vendor endpoint)
  Future<Restaurant> updateRestaurant(String token, int id, UpdateRestaurantRequest request) {
    return putObject(
      '/api/vendor/restaurants/$id',
      'restaurant',
      request.toJson(),
      Restaurant.fromJson,
      token: token,
    );
  }

  // Delete a restaurant (vendor endpoint)
  Future<void> deleteRestaurant(String token, int id) {
    return deleteResource('/api/vendor/restaurants/$id', token: token);
  }

  // ============================================================================
  // Admin-specific methods
  // ============================================================================

  // Get all vendor-restaurant associations (admin endpoint)
  Future<List<Map<String, dynamic>>> getVendorRestaurants(String token) async {
    try {
      final response = await httpClient.get(
        '/api/admin/vendor-restaurants',
        headers: authHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        developer.log('Parsed JSON: $data', name: serviceName);

        final vendorRestaurantsData = data['vendor_restaurants'];
        if (vendorRestaurantsData == null) {
          developer.log('Vendor restaurants field is null, returning empty list', name: serviceName);
          return [];
        }

        if (vendorRestaurantsData is! List) {
          developer.log('Vendor restaurants field is not a List: $vendorRestaurantsData', name: serviceName);
          return [];
        }

        developer.log('Found ${vendorRestaurantsData.length} vendor-restaurant associations', name: serviceName);

        return vendorRestaurantsData.map((json) => json as Map<String, dynamic>).toList();
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load vendor restaurants');
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error in getVendorRestaurants',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // Get a specific vendor-restaurant association by ID (admin endpoint)
  Future<Map<String, dynamic>> getVendorRestaurant(String token, int id) async {
    try {
      final response = await httpClient.get(
        '/api/admin/vendor-restaurants/$id',
        headers: authHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        developer.log('Parsed JSON: $data', name: serviceName);
        return data as Map<String, dynamic>;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load vendor restaurant');
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error in getVendorRestaurant',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // Delete a vendor-restaurant association (admin endpoint)
  Future<void> deleteVendorRestaurant(String token, int id) {
    return deleteResource('/api/admin/vendor-restaurants/$id', token: token);
  }

  // Transfer restaurant ownership to a new vendor (admin endpoint)
  Future<void> transferRestaurantOwnership(String token, int restaurantId, int newVendorId) {
    return executeVoidOperation(
      () => httpClient.put(
        '/api/admin/restaurants/$restaurantId/transfer',
        headers: authHeaders(token),
        body: {'new_vendor_id': newVendorId},
      ),
      'transfer restaurant ownership',
    );
  }

  // ============================================================================
  // Restaurant Settings
  // ============================================================================

  /// Gets the average preparation time for a restaurant in minutes.
  ///
  /// Fetches restaurant settings from the backend API to get the configured
  /// average prep time. This is used to pre-populate the prep time input when
  /// vendors confirm orders.
  ///
  /// The vendor can override this value for specific orders based on complexity.
  ///
  /// Returns the average prep time in minutes, or 30 minutes as a default if
  /// the API call fails or returns no data.
  Future<int> getAveragePrepTime(String token, int restaurantId) async {
    try {
      developer.log(
        '⏱️  Getting average prep time for restaurant $restaurantId',
        name: serviceName,
      );

      final response = await httpClient.get(
        '/api/vendor/restaurant/$restaurantId/settings',
        headers: authHeaders(token),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        developer.log('✅ Received restaurant settings', name: serviceName);

        if (json['success'] == true && json['data'] != null) {
          final data = json['data'] as Map<String, dynamic>;
          final prepTime = data['average_prep_time_minutes'] as int?;

          if (prepTime != null) {
            developer.log('📋 Average prep time: $prepTime minutes',
                name: serviceName);
            return prepTime;
          }
        }
      }

      // If API call fails or returns no data, use default
      const defaultPrepTime = 30;
      developer.log(
        '⚠️  Using default prep time: $defaultPrepTime minutes (API returned no data)',
        name: serviceName,
      );
      return defaultPrepTime;
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error getting prep time: $e',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );

      // Return default on error
      developer.log('📋 Falling back to default: 30 minutes',
          name: serviceName);
      return 30;
    }
  }

  /// Get restaurant settings including hours of operation and prep time
  /// GET /api/vendor/restaurant/{restaurantId}/settings
  Future<VendorSettings> getRestaurantSettings(String token, int restaurantId) async {
    try {
      developer.log(
        '🔧 Getting restaurant settings for restaurant $restaurantId',
        name: serviceName,
      );

      final response = await httpClient.get(
        '/api/vendor/restaurant/$restaurantId/settings',
        headers: authHeaders(token),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        developer.log('✅ Received restaurant settings response', name: serviceName);

        if (json['success'] == true && json['data'] != null) {
          final data = json['data'] as Map<String, dynamic>;
          final settings = VendorSettings.fromJson(data);
          developer.log(
            '📋 Loaded settings: prep time ${settings.averagePrepTimeMinutes} min, hours: ${settings.hoursOfOperation != null ? "configured" : "not set"}',
            name: serviceName,
          );
          return settings;
        }
      }

      throw Exception('Failed to load restaurant settings');
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error getting restaurant settings: $e',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update restaurant settings (hours of operation and/or prep time)
  /// PUT /api/vendor/restaurant/{restaurantId}/settings
  Future<VendorSettings> updateRestaurantSettings(
    String token,
    int restaurantId,
    UpdateVendorSettingsRequest request,
  ) async {
    try {
      developer.log(
        '🔧 Updating restaurant settings for restaurant $restaurantId',
        name: serviceName,
      );

      if (!request.hasUpdates) {
        throw Exception('At least one field must be updated');
      }

      final response = await httpClient.put(
        '/api/vendor/restaurant/$restaurantId/settings',
        headers: authHeaders(token),
        body: request.toJson(),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        developer.log('✅ Successfully updated restaurant settings', name: serviceName);

        if (json['success'] == true && json['data'] != null) {
          final data = json['data'] as Map<String, dynamic>;
          return VendorSettings.fromJson(data);
        }
      }

      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to update restaurant settings');
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error updating restaurant settings: $e',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update only the average prep time (quick update)
  /// PATCH /api/vendor/restaurant/{restaurantId}/prep-time
  Future<void> updateRestaurantPrepTime(
    String token,
    int restaurantId,
    int prepTimeMinutes,
  ) async {
    try {
      developer.log(
        '⏱️  Updating prep time to $prepTimeMinutes minutes for restaurant $restaurantId',
        name: serviceName,
      );

      if (prepTimeMinutes < 1 || prepTimeMinutes > 300) {
        throw Exception('Prep time must be between 1 and 300 minutes');
      }

      final response = await httpClient.patch(
        '/api/vendor/restaurant/$restaurantId/prep-time',
        headers: authHeaders(token),
        body: {'average_prep_time_minutes': prepTimeMinutes},
      );

      if (response.statusCode == 200) {
        developer.log('✅ Successfully updated prep time', name: serviceName);
        return;
      }

      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to update prep time');
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error updating prep time: $e',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
