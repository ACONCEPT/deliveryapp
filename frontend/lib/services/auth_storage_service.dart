import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:developer' as developer;
import '../models/user.dart';

/// Service for securely storing and retrieving authentication data
class AuthStorageService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';
  static const String _profileKey = 'auth_profile';

  final FlutterSecureStorage _storage;

  AuthStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
            );

  /// Save JWT token to secure storage
  Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
      developer.log('Token saved successfully', name: 'AuthStorage');
    } catch (e) {
      developer.log('Error saving token', name: 'AuthStorage', error: e);
      rethrow;
    }
  }

  /// Retrieve JWT token from secure storage
  Future<String?> getToken() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      developer.log(
        'Token retrieved: ${token != null ? "exists" : "null"}',
        name: 'AuthStorage',
      );
      return token;
    } catch (e) {
      developer.log('Error retrieving token', name: 'AuthStorage', error: e);
      return null;
    }
  }

  /// Delete JWT token from secure storage
  Future<void> deleteToken() async {
    try {
      await _storage.delete(key: _tokenKey);
      developer.log('Token deleted successfully', name: 'AuthStorage');
    } catch (e) {
      developer.log('Error deleting token', name: 'AuthStorage', error: e);
      rethrow;
    }
  }

  /// Save user data to secure storage
  Future<void> saveUser(User user) async {
    try {
      final userJson = jsonEncode(user.toJson());
      await _storage.write(key: _userKey, value: userJson);
      developer.log('User saved successfully', name: 'AuthStorage');
    } catch (e) {
      developer.log('Error saving user', name: 'AuthStorage', error: e);
      rethrow;
    }
  }

  /// Retrieve user data from secure storage
  Future<User?> getUser() async {
    try {
      final userJson = await _storage.read(key: _userKey);
      if (userJson == null) {
        developer.log('No user data found', name: 'AuthStorage');
        return null;
      }
      final user = User.fromJson(jsonDecode(userJson));
      developer.log('User retrieved successfully', name: 'AuthStorage');
      return user;
    } catch (e) {
      developer.log('Error retrieving user', name: 'AuthStorage', error: e);
      return null;
    }
  }

  /// Delete user data from secure storage
  Future<void> deleteUser() async {
    try {
      await _storage.delete(key: _userKey);
      developer.log('User deleted successfully', name: 'AuthStorage');
    } catch (e) {
      developer.log('Error deleting user', name: 'AuthStorage', error: e);
      rethrow;
    }
  }

  /// Save user profile data to secure storage
  Future<void> saveProfile(Map<String, dynamic> profile) async {
    try {
      final profileJson = jsonEncode(profile);
      await _storage.write(key: _profileKey, value: profileJson);
      developer.log('Profile saved successfully', name: 'AuthStorage');
    } catch (e) {
      developer.log('Error saving profile', name: 'AuthStorage', error: e);
      rethrow;
    }
  }

  /// Retrieve user profile data from secure storage
  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final profileJson = await _storage.read(key: _profileKey);
      if (profileJson == null) {
        developer.log('No profile data found', name: 'AuthStorage');
        return null;
      }
      final profile = jsonDecode(profileJson) as Map<String, dynamic>;
      developer.log('Profile retrieved successfully', name: 'AuthStorage');
      return profile;
    } catch (e) {
      developer.log('Error retrieving profile', name: 'AuthStorage', error: e);
      return null;
    }
  }

  /// Delete user profile data from secure storage
  Future<void> deleteProfile() async {
    try {
      await _storage.delete(key: _profileKey);
      developer.log('Profile deleted successfully', name: 'AuthStorage');
    } catch (e) {
      developer.log('Error deleting profile', name: 'AuthStorage', error: e);
      rethrow;
    }
  }

  /// Clear all authentication data
  Future<void> clearAll() async {
    try {
      await Future.wait([
        deleteToken(),
        deleteUser(),
        deleteProfile(),
      ]);
      developer.log('All auth data cleared successfully', name: 'AuthStorage');
    } catch (e) {
      developer.log('Error clearing auth data', name: 'AuthStorage', error: e);
      rethrow;
    }
  }

  /// Check if user is authenticated (has token and user data)
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    final user = await getUser();
    return token != null && user != null;
  }
}
