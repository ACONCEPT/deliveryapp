import 'base/json_parsers.dart';

class User {
  final int id;
  final String username;
  final String email;
  final String userType;
  final String userRole;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.userType,
    required this.userRole,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    try {
      print('[User.fromJson] Parsing user JSON: $json');

      // Validate required fields
      if (json['id'] == null) throw Exception('Missing required field: id');
      if (json['username'] == null) throw Exception('Missing required field: username');
      if (json['email'] == null) throw Exception('Missing required field: email');
      if (json['user_type'] == null) throw Exception('Missing required field: user_type');
      if (json['status'] == null) throw Exception('Missing required field: status');
      if (json['created_at'] == null) throw Exception('Missing required field: created_at');
      if (json['updated_at'] == null) throw Exception('Missing required field: updated_at');

      final user = User(
        id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
        username: json['username'].toString(),
        email: json['email'].toString(),
        userType: json['user_type'].toString(),
        userRole: (json['user_role'] ?? json['user_type']).toString(), // Fallback to user_type if not provided
        status: json['status'].toString(),
        createdAt: JsonParsers.parseDateTime(json['created_at']) ?? DateTime.now(),
        updatedAt: JsonParsers.parseDateTime(json['updated_at']) ?? DateTime.now(),
      );

      print('[User.fromJson] Successfully parsed user: ${user.username} (${user.userType})');
      return user;
    } catch (e, stackTrace) {
      print('[User.fromJson] ERROR parsing user JSON: $e');
      print('[User.fromJson] JSON was: $json');
      print('[User.fromJson] Stack trace: $stackTrace');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'user_type': userType,
      'user_role': userRole,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Login response with token, user, and profile data.
/// Structure: { success, message, token?, user?, profile? }
class LoginResponse {
  final bool success;
  final String message;
  final String? token;
  final User? user;
  final Map<String, dynamic>? profile;

  LoginResponse({
    required this.success,
    required this.message,
    this.token,
    this.user,
    this.profile,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    try {
      print('[LoginResponse.fromJson] Parsing login response JSON');
      print('  success: ${json['success']}');
      print('  message: ${json['message']}');
      print('  token present: ${json['token'] != null}');
      print('  user present: ${json['user'] != null}');
      print('  profile present: ${json['profile'] != null}');

      final response = LoginResponse(
        success: json['success'] ?? false,
        message: json['message'] ?? 'Unknown error',
        token: json['token'],
        user: json['user'] != null ? User.fromJson(json['user']) : null,
        profile: json['profile'],
      );

      print('[LoginResponse.fromJson] Successfully parsed login response');
      return response;
    } catch (e, stackTrace) {
      print('[LoginResponse.fromJson] ERROR parsing login response: $e');
      print('[LoginResponse.fromJson] JSON was: $json');
      print('[LoginResponse.fromJson] Stack trace: $stackTrace');
      rethrow;
    }
  }
}

/// Signup response with user ID.
/// Can be replaced with ApiResponse<int> if needed, but keeping for backward compatibility.
/// Structure: { success, message, user_id? }
class SignupResponse {
  final bool success;
  final String message;
  final int? userId;

  SignupResponse({
    required this.success,
    required this.message,
    this.userId,
  });

  factory SignupResponse.fromJson(Map<String, dynamic> json) {
    return SignupResponse(
      success: json['success'],
      message: json['message'],
      userId: json['user_id'],
    );
  }
}
