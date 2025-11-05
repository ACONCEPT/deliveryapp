/// Generic enum parsing utilities to reduce duplication across enum types.
class EnumHelpers {
  /// Parses an enum value from a string by matching the enum's name.
  /// Case-insensitive matching on the enum value name (part after the dot).
  ///
  /// Example:
  /// ```dart
  /// enum Status { pending, approved, rejected }
  ///
  /// final status = EnumHelpers.enumFromString(
  ///   Status.values,
  ///   'approved',
  /// );
  /// // Returns Status.approved
  /// ```
  ///
  /// Throws [ArgumentError] if no match is found and [defaultValue] is null.
  static T enumFromString<T>(
    List<T> values,
    String value, {
    T? defaultValue,
  }) {
    try {
      return values.firstWhere(
        (e) => e.toString().split('.').last.toLowerCase() == value.toLowerCase(),
      );
    } catch (e) {
      if (defaultValue != null) {
        return defaultValue;
      }
      throw ArgumentError('Invalid enum value: $value');
    }
  }

  /// Converts an enum value to its string representation (name only).
  ///
  /// Example:
  /// ```dart
  /// enum Status { pending, approved }
  ///
  /// final str = EnumHelpers.enumToString(Status.approved);
  /// // Returns 'approved'
  /// ```
  static String enumToString<T>(T enumValue) {
    return enumValue.toString().split('.').last;
  }

  /// Parses an enum value from a string, returning null if not found.
  /// Case-insensitive matching on the enum value name.
  ///
  /// Example:
  /// ```dart
  /// final status = EnumHelpers.enumFromStringOrNull(
  ///   Status.values,
  ///   'unknown',
  /// );
  /// // Returns null
  /// ```
  static T? enumFromStringOrNull<T>(List<T> values, String? value) {
    if (value == null) return null;
    try {
      return values.firstWhere(
        (e) => e.toString().split('.').last.toLowerCase() == value.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }
}
