import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'dart:developer' as developer;
import '../models/user.dart';

class AuthProvider with ChangeNotifier {
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _usernameKey = 'username';
  static const String _userTypeKey = 'user_type';

  String? _token;
  User? _user;
  Map<String, dynamic>? _profile;
  bool _isInitialized = false;

  // Getters
  String? get token => _token;
  User? get user => _user;
  Map<String, dynamic>? get profile => _profile;
  bool get isAuthenticated => _token != null && !isTokenExpired;
  bool get isInitialized => _isInitialized;

  // Check if token is expired
  bool get isTokenExpired {
    if (_token == null) return true;
    try {
      return JwtDecoder.isExpired(_token!);
    } catch (e) {
      developer.log('⚠️ JWT decode error (treating as valid, backend will validate): $e',
        name: 'AuthProvider', error: e);
      // Return false to allow authentication despite decode error
      // The backend will validate the token on API calls
      return false;
    }
  }

  // Get token expiration time
  DateTime? get tokenExpirationDate {
    if (_token == null) return null;
    try {
      return JwtDecoder.getExpirationDate(_token!);
    } catch (e) {
      developer.log('Error getting token expiration: $e',
        name: 'AuthProvider', error: e);
      return null;
    }
  }

  // Get token decoded payload
  Map<String, dynamic>? get tokenPayload {
    if (_token == null) return null;
    try {
      return JwtDecoder.decode(_token!);
    } catch (e) {
      developer.log('Error decoding token: $e',
        name: 'AuthProvider', error: e);
      return null;
    }
  }

  // Initialize auth state from storage
  Future<void> initialize() async {
    developer.log('🔵 AuthProvider.initialize() called', name: 'AuthProvider');
    try {
      developer.log('  Getting SharedPreferences instance...', name: 'AuthProvider');
      final prefs = await SharedPreferences.getInstance();
      developer.log('  SharedPreferences obtained', name: 'AuthProvider');

      _token = prefs.getString(_tokenKey);
      developer.log('  Token from storage: ${_token != null ? "EXISTS" : "NULL"}', name: 'AuthProvider');

      if (_token != null) {
        developer.log('  Checking token expiration...', name: 'AuthProvider');
        // Check if token is expired
        if (isTokenExpired) {
          developer.log('⚠️  Stored token is expired, clearing auth',
            name: 'AuthProvider');
          await clearAuth();
        } else {
          developer.log('✅ Token is valid', name: 'AuthProvider');
          // Restore user info from preferences
          final userId = prefs.getInt(_userIdKey);
          final username = prefs.getString(_usernameKey);
          final userType = prefs.getString(_userTypeKey);

          developer.log('  User info - userId: $userId, username: $username, userType: $userType',
            name: 'AuthProvider');

          if (userId != null && username != null && userType != null) {
            // Reconstruct minimal user object
            // Note: Full user data should be fetched from /api/profile
            developer.log('✅ Auth restored from storage for user: $username',
              name: 'AuthProvider');
          }
        }
      } else {
        developer.log('  No token in storage - user not logged in', name: 'AuthProvider');
      }

      _isInitialized = true;
      developer.log('✅ AuthProvider initialized successfully', name: 'AuthProvider');
      notifyListeners();
    } catch (e, stackTrace) {
      developer.log('❌ Error initializing auth: $e',
        name: 'AuthProvider', error: e, stackTrace: stackTrace);
      _isInitialized = true;
      developer.log('⚠️  Set isInitialized=true despite error', name: 'AuthProvider');
      notifyListeners();
    }
  }

  // Set authentication data after login
  Future<void> setAuth({
    required String token,
    required User user,
    Map<String, dynamic>? profile,
  }) async {
    try {
      _token = token;
      _user = user;
      _profile = profile;

      // Persist to storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setInt(_userIdKey, user.id);
      await prefs.setString(_usernameKey, user.username);
      await prefs.setString(_userTypeKey, user.userType);

      developer.log('✅ Auth set for user: ${user.username} (${user.userType})',
        name: 'AuthProvider');
      developer.log('Token expires: ${tokenExpirationDate}',
        name: 'AuthProvider');

      notifyListeners();
    } catch (e) {
      developer.log('❌ Error setting auth: $e',
        name: 'AuthProvider', error: e);
      rethrow;
    }
  }

  // Clear authentication data (logout)
  Future<void> clearAuth() async {
    try {
      _token = null;
      _user = null;
      _profile = null;

      // Clear from storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_usernameKey);
      await prefs.remove(_userTypeKey);

      developer.log('🔓 Auth cleared (logout)', name: 'AuthProvider');

      notifyListeners();
    } catch (e) {
      developer.log('Error clearing auth: $e',
        name: 'AuthProvider', error: e);
    }
  }

  // Update user profile
  void updateProfile(Map<String, dynamic> profile) {
    _profile = profile;
    developer.log('Profile updated', name: 'AuthProvider');
    notifyListeners();
  }

  // Get debug info for development
  Map<String, dynamic> getDebugInfo() {
    return {
      'is_authenticated': isAuthenticated,
      'is_token_expired': isTokenExpired,
      'token_length': _token?.length ?? 0,
      'token_preview': _token != null ? '${_token!.substring(0, 20)}...' : null,
      'token_expiration': tokenExpirationDate?.toIso8601String(),
      'token_payload': tokenPayload,
      'user': _user?.toJson(),
      'profile': _profile,
    };
  }
}
