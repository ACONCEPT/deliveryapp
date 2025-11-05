import 'dart:convert';

/// Centralized JSON parsing utilities to reduce code duplication across models.
/// Provides consistent handling of nullable values, type conversions, and nested objects.
class JsonParsers {
  /// Parses a DateTime from various JSON value formats.
  /// Returns null if value is null or parsing fails.
  ///
  /// Handles:
  /// - null values -> null
  /// - String values -> DateTime.parse()
  /// - Invalid strings -> null (catches exceptions)
  static DateTime? parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Parses a DateTime from Go's sql.NullTime format or standard formats.
  /// Returns null if value is null, invalid, or represents a zero/null time.
  ///
  /// Handles:
  /// - null values -> null
  /// - String values -> DateTime.parse()
  /// - Map with 'Time' and 'Valid' keys (Go sql.NullTime) -> DateTime if Valid is true
  /// - Zero dates (year <= 1) -> null
  static DateTime? parseDateTimeWithNullable(dynamic value) {
    if (value == null) return null;

    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }

    if (value is Map<String, dynamic>) {
      if (value.containsKey('Time') && value['Valid'] == true) {
        final timeStr = value['Time'];
        if (timeStr is String) {
          try {
            final dt = DateTime.parse(timeStr);
            // Filter out zero/null times (Go default for null sql.NullTime)
            if (dt.year > 1) return dt;
          } catch (e) {
            return null;
          }
        }
      }
    }

    return null;
  }

  /// Parses a double from various numeric JSON value formats.
  /// Returns null if value is null or cannot be converted.
  ///
  /// Handles:
  /// - null values -> null
  /// - num values (int or double) -> double
  /// - String values -> double.tryParse()
  static double? parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Parses a double with a fallback default value.
  /// Returns the parsed double or defaultValue if parsing fails.
  static double parseDoubleWithDefault(dynamic value, double defaultValue) {
    return parseDouble(value) ?? defaultValue;
  }

  /// Extracts an integer ID from various JSON value formats.
  /// Returns null if value is null or cannot be extracted.
  ///
  /// Handles:
  /// - null values -> null
  /// - int values -> int
  /// - Map with 'Int64' and 'Valid' keys (Go sql.NullInt64) -> int if Valid is true
  /// - Map with 'id' key -> int
  static int? extractId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;

    if (value is Map<String, dynamic>) {
      // Handle Go's sql.NullInt64 format
      if (value.containsKey('Int64') && value['Valid'] == true) {
        return value['Int64'] as int?;
      }
      // Handle nested object with id field
      if (value.containsKey('id')) {
        return value['id'] as int?;
      }
    }

    return null;
  }

  /// Extracts a string from various JSON value formats.
  /// Returns null if value is null, empty, or cannot be extracted.
  ///
  /// Handles:
  /// - null values -> null
  /// - String values -> String (if not empty)
  /// - Map with 'String' and 'Valid' keys (Go sql.NullString) -> String if Valid is true
  /// - Map with specified key -> String
  ///
  /// [key] is used when extracting from nested objects to specify which field to extract.
  static String? extractString(dynamic value, [String? key]) {
    if (value == null) return null;

    if (value is String) {
      return value.isNotEmpty ? value : null;
    }

    if (value is Map<String, dynamic>) {
      // Handle Go's sql.NullString format
      if (value.containsKey('String') && value['Valid'] == true) {
        final str = value['String'];
        return (str is String && str.isNotEmpty) ? str : null;
      }

      // Handle nested object with specified key
      if (key != null && value.containsKey(key)) {
        final extracted = value[key];
        if (extracted is String && extracted.isNotEmpty) {
          return extracted;
        }
      }
    }

    return null;
  }

  /// Parses a JSON field that may be encoded as a string or already be a Map.
  /// Returns an empty Map if parsing fails or value is null.
  ///
  /// Handles:
  /// - null values -> {}
  /// - Map values -> Map (as is)
  /// - String values -> jsonDecode() to Map
  /// - Invalid JSON -> {} (catches exceptions)
  static Map<String, dynamic> parseJsonField(dynamic value) {
    if (value == null) return {};
    if (value is Map<String, dynamic>) return value;

    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        return decoded is Map<String, dynamic> ? decoded : {};
      } catch (e) {
        return {};
      }
    }

    return {};
  }

  /// Encodes a Map to a JSON string.
  /// This is a convenience wrapper around jsonEncode for consistency.
  static String encodeJsonField(Map<String, dynamic> value) {
    return jsonEncode(value);
  }

  /// Parses a list from various JSON value formats.
  /// Returns an empty list if value is null or not a list.
  ///
  /// Handles:
  /// - null values -> []
  /// - List values -> List<T> (with item parser)
  /// - Non-list values -> []
  ///
  /// [json] is the JSON map containing the list
  /// [key] is the field name to extract
  /// [itemParser] is a function to convert each list item to type T.
  static List<T> parseList<T>(
    Map<String, dynamic> json,
    String key,
    T Function(dynamic) itemParser,
  ) {
    final value = json[key];
    if (value == null) return [];
    if (value is! List) return [];

    return value.map((item) => itemParser(item)).toList();
  }

  /// Parses an integer from various JSON value formats.
  /// Returns null if value is null or cannot be converted.
  ///
  /// Handles:
  /// - null values -> null
  /// - int values -> int
  /// - String values -> int.tryParse()
  static int? parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Parses a boolean from various JSON value formats.
  /// Returns false if value is null or cannot be converted.
  ///
  /// Handles:
  /// - null values -> false
  /// - bool values -> bool
  /// - String values -> true if 'true' (case insensitive)
  /// - int values -> true if non-zero
  static bool parseBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is int) return value != 0;
    return defaultValue;
  }
}
