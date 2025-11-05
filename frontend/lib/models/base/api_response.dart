/// Generic API response wrapper classes to reduce duplication in model response types.
/// Provides consistent structure for success/error responses from the backend.
library;

/// Generic API response wrapper for single data objects.
///
/// Use this when the API returns a single object with success/message fields.
/// Example:
/// ```dart
/// final response = ApiResponse<User>.fromJson(
///   jsonData,
///   (data) => User.fromJson(data),
/// );
/// ```
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>)? dataParser,
  ) {
    return ApiResponse<T>(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null && dataParser != null
          ? dataParser(json['data'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson(Map<String, dynamic> Function(T)? dataSerializer) {
    return {
      'success': success,
      'message': message,
      if (data != null && dataSerializer != null) 'data': dataSerializer(data as T),
    };
  }
}

/// Generic API response wrapper for list data.
///
/// Use this when the API returns a list of objects with success/message fields.
/// Example:
/// ```dart
/// final response = ApiListResponse<User>.fromJson(
///   jsonData,
///   (item) => User.fromJson(item),
/// );
/// ```
class ApiListResponse<T> {
  final bool success;
  final String message;
  final List<T> data;

  ApiListResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory ApiListResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemParser,
  ) {
    return ApiListResponse<T>(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null
          ? (json['data'] as List)
              .map((item) => itemParser(item as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson(Map<String, dynamic> Function(T) itemSerializer) {
    return {
      'success': success,
      'message': message,
      'data': data.map((item) => itemSerializer(item)).toList(),
    };
  }
}

/// Simple success/error response without data payload.
///
/// Use this for operations that only return success status and message.
/// Example:
/// ```dart
/// final response = SimpleResponse.fromJson(jsonData);
/// if (response.success) {
///   print(response.message);
/// }
/// ```
class SimpleResponse {
  final bool success;
  final String message;

  SimpleResponse({
    required this.success,
    required this.message,
  });

  factory SimpleResponse.fromJson(Map<String, dynamic> json) {
    return SimpleResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
    };
  }
}

/// Generic API response with string data (commonly used for IDs, tokens, etc).
///
/// Use this when the API returns a simple string value.
/// Example:
/// ```dart
/// final response = StringDataResponse.fromJson(jsonData);
/// final token = response.data;
/// ```
class StringDataResponse {
  final bool success;
  final String message;
  final String? data;

  StringDataResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory StringDataResponse.fromJson(Map<String, dynamic> json) {
    return StringDataResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      if (data != null) 'data': data,
    };
  }
}

/// Generic API response with integer data (commonly used for counts, IDs, etc).
///
/// Use this when the API returns a simple integer value.
/// Example:
/// ```dart
/// final response = IntDataResponse.fromJson(jsonData);
/// final count = response.data;
/// ```
class IntDataResponse {
  final bool success;
  final String message;
  final int? data;

  IntDataResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory IntDataResponse.fromJson(Map<String, dynamic> json) {
    return IntDataResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      if (data != null) 'data': data,
    };
  }
}

/// Generic API response with boolean data.
///
/// Use this when the API returns a simple boolean value.
/// Example:
/// ```dart
/// final response = BoolDataResponse.fromJson(jsonData);
/// final isAvailable = response.data;
/// ```
class BoolDataResponse {
  final bool success;
  final String message;
  final bool? data;

  BoolDataResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory BoolDataResponse.fromJson(Map<String, dynamic> json) {
    return BoolDataResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      if (data != null) 'data': data,
    };
  }
}
