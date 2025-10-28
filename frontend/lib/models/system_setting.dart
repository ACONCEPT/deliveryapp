/// System settings data models for admin configuration management
///
/// Models for system-wide configuration settings that can be managed by administrators.
/// Settings are grouped by category and support different data types (string, number, boolean, json).

/// Enum representing supported data types for system settings
enum SettingDataType {
  string,
  number,
  boolean,
  json;

  /// Convert string to SettingDataType enum
  static SettingDataType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'string':
        return SettingDataType.string;
      case 'number':
        return SettingDataType.number;
      case 'boolean':
        return SettingDataType.boolean;
      case 'json':
        return SettingDataType.json;
      default:
        throw ArgumentError('Unknown data type: $type');
    }
  }

  /// Convert enum to string for API
  String toApiString() {
    return name;
  }

  /// Get display name for UI
  String get displayName {
    switch (this) {
      case SettingDataType.string:
        return 'Text';
      case SettingDataType.number:
        return 'Number';
      case SettingDataType.boolean:
        return 'True/False';
      case SettingDataType.json:
        return 'JSON';
    }
  }
}

/// Individual system setting model
class SystemSetting {
  final int id;
  final String settingKey;
  final String settingValue; // Stored as string, typed by dataType
  final SettingDataType dataType;
  final String description;
  final String category;
  final bool isEditable;
  final DateTime createdAt;
  final DateTime updatedAt;

  SystemSetting({
    required this.id,
    required this.settingKey,
    required this.settingValue,
    required this.dataType,
    required this.description,
    required this.category,
    required this.isEditable,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Parse setting value as appropriate type based on dataType
  dynamic get typedValue {
    switch (dataType) {
      case SettingDataType.string:
        return settingValue;
      case SettingDataType.number:
        return double.tryParse(settingValue);
      case SettingDataType.boolean:
        return settingValue.toLowerCase() == 'true';
      case SettingDataType.json:
        // Return string for now, parsing can be done by consumer
        return settingValue;
    }
  }

  /// Get numeric value (for number type settings)
  double? get numberValue {
    if (dataType == SettingDataType.number) {
      return double.tryParse(settingValue);
    }
    return null;
  }

  /// Get boolean value (for boolean type settings)
  bool? get booleanValue {
    if (dataType == SettingDataType.boolean) {
      return settingValue.toLowerCase() == 'true';
    }
    return null;
  }

  /// Get string value (always available)
  String get stringValue => settingValue;

  /// Create from JSON
  factory SystemSetting.fromJson(Map<String, dynamic> json) {
    return SystemSetting(
      id: json['id'] as int,
      settingKey: json['setting_key'] as String,
      settingValue: json['setting_value'] as String,
      dataType: SettingDataType.fromString(json['data_type'] as String),
      description: json['description'] as String,
      category: json['category'] as String,
      isEditable: json['is_editable'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'setting_key': settingKey,
      'setting_value': settingValue,
      'data_type': dataType.toApiString(),
      'description': description,
      'category': category,
      'is_editable': isEditable,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create copy with updated fields
  SystemSetting copyWith({
    int? id,
    String? settingKey,
    String? settingValue,
    SettingDataType? dataType,
    String? description,
    String? category,
    bool? isEditable,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SystemSetting(
      id: id ?? this.id,
      settingKey: settingKey ?? this.settingKey,
      settingValue: settingValue ?? this.settingValue,
      dataType: dataType ?? this.dataType,
      description: description ?? this.description,
      category: category ?? this.category,
      isEditable: isEditable ?? this.isEditable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get formatted display value based on type
  String get formattedValue {
    switch (dataType) {
      case SettingDataType.boolean:
        return booleanValue == true ? 'Enabled' : 'Disabled';
      case SettingDataType.number:
        final num = numberValue;
        if (num == null) return settingValue;
        // Format as currency if key contains 'amount', 'fee', or 'price'
        if (settingKey.contains('amount') ||
            settingKey.contains('fee') ||
            settingKey.contains('price')) {
          return '\$${num.toStringAsFixed(2)}';
        }
        // Format as percentage if key contains 'rate' or 'commission'
        if (settingKey.contains('rate') || settingKey.contains('commission')) {
          return '${(num * 100).toStringAsFixed(1)}%';
        }
        return num.toString();
      case SettingDataType.string:
      case SettingDataType.json:
        return settingValue;
    }
  }
}

/// Response from GET /api/admin/settings
class SettingsResponse {
  final bool success;
  final String message;
  final Map<String, List<SystemSetting>> settings; // Settings grouped by category
  final int totalCount;
  final int categoriesCount;

  SettingsResponse({
    required this.success,
    required this.message,
    required this.settings,
    required this.totalCount,
    required this.categoriesCount,
  });

  /// Create from JSON
  factory SettingsResponse.fromJson(Map<String, dynamic> json) {
    final settingsData = json['data'] as Map<String, dynamic>;
    final settingsByCategory =
        settingsData['settings'] as Map<String, dynamic>;

    // Parse settings grouped by category
    final Map<String, List<SystemSetting>> parsedSettings = {};
    settingsByCategory.forEach((category, settingsList) {
      parsedSettings[category] = (settingsList as List)
          .map((s) => SystemSetting.fromJson(s as Map<String, dynamic>))
          .toList();
    });

    return SettingsResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      settings: parsedSettings,
      totalCount: settingsData['total_count'] as int,
      categoriesCount: settingsData['categories_count'] as int,
    );
  }

  /// Get all settings as flat list
  List<SystemSetting> get allSettings {
    return settings.values.expand((list) => list).toList();
  }

  /// Get settings for a specific category
  List<SystemSetting> getSettingsForCategory(String category) {
    return settings[category] ?? [];
  }

  /// Get all category names
  List<String> get categories {
    return settings.keys.toList();
  }
}

/// Request to update a single setting
class UpdateSettingRequest {
  final String value;

  UpdateSettingRequest({required this.value});

  Map<String, dynamic> toJson() {
    return {
      'value': value,
    };
  }
}

/// Single setting update for batch operation
class BatchUpdateSettingRequest {
  final String key;
  final String value;

  BatchUpdateSettingRequest({
    required this.key,
    required this.value,
  });

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'value': value,
    };
  }
}

/// Request to update multiple settings in one transaction
class UpdateMultipleSettingsRequest {
  final List<BatchUpdateSettingRequest> settings;

  UpdateMultipleSettingsRequest({required this.settings});

  Map<String, dynamic> toJson() {
    return {
      'settings': settings.map((s) => s.toJson()).toList(),
    };
  }
}

/// Result from batch update operation
class BatchUpdateResult {
  final int successCount;
  final int failureCount;
  final List<BatchUpdateError> errors;
  final List<String> updatedKeys;

  BatchUpdateResult({
    required this.successCount,
    required this.failureCount,
    required this.errors,
    required this.updatedKeys,
  });

  factory BatchUpdateResult.fromJson(Map<String, dynamic> json) {
    return BatchUpdateResult(
      successCount: json['success_count'] as int,
      failureCount: json['failure_count'] as int,
      errors: (json['errors'] as List? ?? [])
          .map((e) => BatchUpdateError.fromJson(e as Map<String, dynamic>))
          .toList(),
      updatedKeys: (json['updated_keys'] as List? ?? [])
          .map((k) => k as String)
          .toList(),
    );
  }

  bool get hasErrors => failureCount > 0;
  bool get allSucceeded => failureCount == 0;
}

/// Error details for failed setting update
class BatchUpdateError {
  final String key;
  final String message;

  BatchUpdateError({
    required this.key,
    required this.message,
  });

  factory BatchUpdateError.fromJson(Map<String, dynamic> json) {
    return BatchUpdateError(
      key: json['key'] as String,
      message: json['message'] as String,
    );
  }
}

/// Response from GET /api/admin/settings/categories
class CategoriesResponse {
  final bool success;
  final String message;
  final List<String> categories;
  final int count;

  CategoriesResponse({
    required this.success,
    required this.message,
    required this.categories,
    required this.count,
  });

  factory CategoriesResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return CategoriesResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      categories:
          (data['categories'] as List).map((c) => c as String).toList(),
      count: data['count'] as int,
    );
  }
}

/// Single setting response wrapper
class SingleSettingResponse {
  final bool success;
  final String message;
  final SystemSetting setting;

  SingleSettingResponse({
    required this.success,
    required this.message,
    required this.setting,
  });

  factory SingleSettingResponse.fromJson(Map<String, dynamic> json) {
    return SingleSettingResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      setting: SystemSetting.fromJson(json['data'] as Map<String, dynamic>),
    );
  }
}

/// Batch update response wrapper
class BatchUpdateResponse {
  final bool success;
  final String message;
  final BatchUpdateResult data;

  BatchUpdateResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory BatchUpdateResponse.fromJson(Map<String, dynamic> json) {
    return BatchUpdateResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      data: BatchUpdateResult.fromJson(json['data'] as Map<String, dynamic>),
    );
  }
}
