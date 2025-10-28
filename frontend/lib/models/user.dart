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
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      userType: json['user_type'],
      userRole: json['user_role'] ?? json['user_type'], // Fallback to user_type if not provided
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
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
    return LoginResponse(
      success: json['success'],
      message: json['message'],
      token: json['token'],
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      profile: json['profile'],
    );
  }
}

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
