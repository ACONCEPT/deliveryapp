import 'dart:convert';
import 'dart:developer' as developer;

/// JWT decoding utilities for extracting claims from tokens
class JwtDecoder {
  /// Decode JWT token and return payload as Map
  static Map<String, dynamic>? decodeToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        developer.log('Invalid JWT format', name: 'JwtDecoder');
        return null;
      }

      // Get payload (middle part)
      final payload = parts[1];

      // Add padding if needed (JWT base64 encoding doesn't include padding)
      String normalized = base64.normalize(payload);

      // Decode base64
      final decoded = utf8.decode(base64.decode(normalized));

      // Parse JSON
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (e) {
      developer.log('Error decoding JWT', name: 'JwtDecoder', error: e);
      return null;
    }
  }

  /// Extract user ID from JWT token
  static int? getUserIdFromToken(String token) {
    final payload = decodeToken(token);
    if (payload == null) return null;

    // Try common claim names
    if (payload.containsKey('user_id')) {
      return payload['user_id'] as int?;
    }
    if (payload.containsKey('userId')) {
      return payload['userId'] as int?;
    }
    if (payload.containsKey('sub')) {
      // 'sub' is standard JWT claim for subject (user ID)
      final sub = payload['sub'];
      if (sub is int) return sub;
      if (sub is String) return int.tryParse(sub);
    }

    return null;
  }

  /// Extract customer ID from JWT token (alias for getUserIdFromToken)
  static int? getCustomerIdFromToken(String token) {
    return getUserIdFromToken(token);
  }

  /// Extract user type/role from JWT token
  static String? getUserTypeFromToken(String token) {
    final payload = decodeToken(token);
    if (payload == null) return null;

    if (payload.containsKey('user_type')) {
      return payload['user_type'] as String?;
    }
    if (payload.containsKey('userType')) {
      return payload['userType'] as String?;
    }
    if (payload.containsKey('role')) {
      return payload['role'] as String?;
    }

    return null;
  }

  /// Check if JWT token is expired
  static bool isTokenExpired(String token) {
    final payload = decodeToken(token);
    if (payload == null) return true;

    if (!payload.containsKey('exp')) {
      developer.log('Token has no expiration claim', name: 'JwtDecoder');
      return false; // No expiration claim, consider valid
    }

    final exp = payload['exp'];
    if (exp is! int) return true;

    // Convert exp (seconds since epoch) to DateTime
    final expirationDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    final now = DateTime.now();

    final expired = now.isAfter(expirationDate);
    if (expired) {
      developer.log(
        'Token expired at $expirationDate (now: $now)',
        name: 'JwtDecoder',
      );
    }

    return expired;
  }

  /// Get token expiration date
  static DateTime? getTokenExpiration(String token) {
    final payload = decodeToken(token);
    if (payload == null) return null;

    final exp = payload['exp'];
    if (exp is! int) return null;

    return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
  }

  /// Get time remaining until token expires
  static Duration? getTimeUntilExpiration(String token) {
    final expiration = getTokenExpiration(token);
    if (expiration == null) return null;

    final now = DateTime.now();
    if (now.isAfter(expiration)) return Duration.zero;

    return expiration.difference(now);
  }

  /// Pretty print token payload for debugging
  static void debugPrintToken(String token) {
    final payload = decodeToken(token);
    if (payload == null) {
      developer.log('Failed to decode token', name: 'JwtDecoder');
      return;
    }

    developer.log(
      'JWT Payload:\n${const JsonEncoder.withIndent('  ').convert(payload)}',
      name: 'JwtDecoder',
    );
  }
}
