import 'dart:developer' as developer;

/// JSON parsing utilities to reduce code duplication across services
class JsonHelpers {
  /// Parses a list from JSON with comprehensive error handling
  ///
  /// [json] - The JSON map containing the data
  /// [key] - The key in the JSON map that contains the list
  /// [fromJson] - Function to convert each item to the target type
  /// [loggerName] - Name to use in log messages (typically the service name)
  ///
  /// Returns an empty list if:
  /// - The key doesn't exist in the JSON
  /// - The value at key is null
  /// - The value at key is not a List
  /// - Any item fails to parse (logs error and skips item)
  static List<T> parseList<T>(
    Map<String, dynamic> json,
    String key,
    T Function(Map<String, dynamic>) fromJson, {
    String loggerName = 'JsonHelpers',
  }) {
    final data = json[key];

    if (data == null) {
      developer.log(
        '$key field is null, returning empty list',
        name: loggerName,
      );
      return [];
    }

    if (data is! List) {
      developer.log(
        '$key field is not a List: $data',
        name: loggerName,
      );
      return [];
    }

    final result = <T>[];
    for (int i = 0; i < data.length; i++) {
      try {
        final item = data[i];
        if (item is Map<String, dynamic>) {
          result.add(fromJson(item));
        } else {
          developer.log(
            '$key[$i] is not a Map<String, dynamic>: $item',
            name: loggerName,
          );
        }
      } catch (e, stackTrace) {
        developer.log(
          'Error parsing $key[$i]',
          name: loggerName,
          error: e,
          stackTrace: stackTrace,
        );
        // Continue parsing other items
      }
    }

    return result;
  }

  /// Parses a single object from JSON with error handling
  ///
  /// [json] - The JSON map containing the data
  /// [key] - The key in the JSON map that contains the object
  /// [fromJson] - Function to convert the object to the target type
  /// [loggerName] - Name to use in log messages
  ///
  /// Returns null if:
  /// - The key doesn't exist in the JSON
  /// - The value at key is null
  /// - The value at key is not a Map
  /// - Parsing fails
  static T? parseObject<T>(
    Map<String, dynamic> json,
    String key,
    T Function(Map<String, dynamic>) fromJson, {
    String loggerName = 'JsonHelpers',
  }) {
    final data = json[key];

    if (data == null) {
      developer.log(
        '$key field is null',
        name: loggerName,
      );
      return null;
    }

    if (data is! Map<String, dynamic>) {
      developer.log(
        '$key field is not a Map<String, dynamic>: $data',
        name: loggerName,
      );
      return null;
    }

    try {
      return fromJson(data);
    } catch (e, stackTrace) {
      developer.log(
        'Error parsing $key',
        name: loggerName,
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Validates that a required field exists in JSON
  ///
  /// Throws [FormatException] if the field is missing or has wrong type
  static T requireField<T>(Map<String, dynamic> json, String key) {
    if (!json.containsKey(key)) {
      throw FormatException('Missing required field: $key');
    }

    final value = json[key];
    if (value is! T) {
      throw FormatException(
        'Field $key has wrong type. Expected $T but got ${value.runtimeType}',
      );
    }

    return value;
  }

  /// Gets a field value with a default if missing or null
  static T getFieldOrDefault<T>(
    Map<String, dynamic> json,
    String key,
    T defaultValue,
  ) {
    final value = json[key];
    return (value is T) ? value : defaultValue;
  }
}
