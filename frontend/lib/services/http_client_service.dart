import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../providers/auth_provider.dart';

/// Centralized HTTP client with comprehensive request/response logging
/// All API services should use this client for consistent logging
class HttpClientService {
  static final String baseUrl = ApiConfig.baseUrl;

  AuthProvider? _authProvider;

  // Singleton pattern
  static final HttpClientService _instance = HttpClientService._internal();
  factory HttpClientService() => _instance;
  HttpClientService._internal();

  /// Set the AuthProvider for automatic token injection
  void setAuthProvider(AuthProvider provider) {
    _authProvider = provider;
  }

  /// Helper method to get auth headers automatically
  Map<String, String> _getHeaders({Map<String, String>? additionalHeaders}) {
    final headers = {
      'Content-Type': 'application/json',
      ...?additionalHeaders,
    };

    // Debug logging
    developer.log('🔍 _getHeaders called', name: 'HttpClientService');
    developer.log('  _authProvider is null? ${_authProvider == null}', name: 'HttpClientService');
    if (_authProvider != null) {
      developer.log('  token is null? ${_authProvider!.token == null}', name: 'HttpClientService');
      if (_authProvider!.token != null) {
        developer.log('  token length: ${_authProvider!.token!.length}', name: 'HttpClientService');
        developer.log('  token expired? ${_authProvider!.isTokenExpired}', name: 'HttpClientService');
      }
    }

    // Automatically add auth token if available
    if (_authProvider != null && _authProvider!.token != null) {
      if (!_authProvider!.isTokenExpired) {
        headers['Authorization'] = 'Bearer ${_authProvider!.token}';
        developer.log('✅ Added Authorization header', name: 'HttpClientService');
      } else {
        developer.log('⚠️  Token is expired, skipping Authorization header',
          name: 'HttpClientService');
      }
    } else {
      developer.log('❌ No auth token available - _authProvider or token is null',
        name: 'HttpClientService');
    }

    return headers;
  }

  /// Log request details with formatted output
  void _logRequest(String method, String url, Map<String, String> headers,
      {String? body}) {
    developer.log(
      '📤 REQUEST: $method $url',
      name: 'HTTP_CLIENT',
      level: 1000,
    );

    // Log headers
    final headerStr = headers.entries.map((e) {
      if (e.key.toLowerCase() == 'authorization') {
        final masked = e.value.length > 20
            ? '${e.value.substring(0, 20)}...[MASKED]'
            : '[MASKED]';
        return '${e.key}: $masked';
      }
      return '${e.key}: ${e.value}';
    }).join(', ');
    developer.log('Headers: $headerStr', name: 'HTTP_CLIENT');

    // Log body
    if (body != null) {
      try {
        final jsonObj = jsonDecode(body);
        final prettyJson = JsonEncoder.withIndent('  ').convert(jsonObj);
        developer.log('Body:\n$prettyJson', name: 'HTTP_CLIENT');
      } catch (e) {
        developer.log('Body: $body', name: 'HTTP_CLIENT');
      }
    }
  }

  /// Log response details with formatted output
  void _logResponse(
      String method, String url, int statusCode, String body) {
    final isSuccess = statusCode >= 200 && statusCode < 300;
    final icon = isSuccess ? '✅' : '❌';

    developer.log(
      '$icon RESPONSE: $method $url - Status: $statusCode',
      name: 'HTTP_CLIENT',
      level: isSuccess ? 800 : 900,
    );

    // Log response body
    try {
      final jsonObj = jsonDecode(body);
      final prettyJson = JsonEncoder.withIndent('  ').convert(jsonObj);
      developer.log('Response:\n$prettyJson', name: 'HTTP_CLIENT', level: isSuccess ? 800 : 900);
    } catch (e) {
      developer.log('Response: $body', name: 'HTTP_CLIENT', level: isSuccess ? 800 : 900);
    }
  }

  /// GET request with logging and timeout
  Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final url = '$baseUrl$path';
    final requestHeaders = _getHeaders(additionalHeaders: headers);

    _logRequest('GET', url, requestHeaders);

    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: requestHeaders,
          )
          .timeout(timeout ?? ApiConfig.requestTimeout);

      _logResponse('GET', url, response.statusCode, response.body);

      // Handle 401 automatically
      if (response.statusCode == 401 && _authProvider != null) {
        developer.log('❌ 401 Unauthorized - clearing auth',
          name: 'HttpClientService');
        await _authProvider!.clearAuth();
      }

      return response;
    } catch (e) {
      developer.log('❌ GET request failed: $e',
          name: 'HTTP_CLIENT', error: e, level: 1000);
      rethrow;
    }
  }

  /// POST request with logging and timeout
  Future<http.Response> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    final url = '$baseUrl$path';
    final requestHeaders = _getHeaders(additionalHeaders: headers);

    final bodyString = body != null ? jsonEncode(body) : null;
    _logRequest('POST', url, requestHeaders, body: bodyString);

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: requestHeaders,
            body: bodyString,
          )
          .timeout(timeout ?? ApiConfig.requestTimeout);

      _logResponse('POST', url, response.statusCode, response.body);

      // Handle 401 automatically
      if (response.statusCode == 401 && _authProvider != null) {
        developer.log('❌ 401 Unauthorized - clearing auth',
          name: 'HttpClientService');
        await _authProvider!.clearAuth();
      }

      return response;
    } catch (e) {
      developer.log('❌ POST request failed: $e',
          name: 'HTTP_CLIENT', error: e, level: 1000);
      rethrow;
    }
  }

  /// PUT request with logging and timeout
  Future<http.Response> put(
    String path, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    final url = '$baseUrl$path';
    final requestHeaders = _getHeaders(additionalHeaders: headers);

    final bodyString = body != null ? jsonEncode(body) : null;
    _logRequest('PUT', url, requestHeaders, body: bodyString);

    try {
      final response = await http
          .put(
            Uri.parse(url),
            headers: requestHeaders,
            body: bodyString,
          )
          .timeout(timeout ?? ApiConfig.requestTimeout);

      _logResponse('PUT', url, response.statusCode, response.body);

      // Handle 401 automatically
      if (response.statusCode == 401 && _authProvider != null) {
        developer.log('❌ 401 Unauthorized - clearing auth',
          name: 'HttpClientService');
        await _authProvider!.clearAuth();
      }

      return response;
    } catch (e) {
      developer.log('❌ PUT request failed: $e',
          name: 'HTTP_CLIENT', error: e, level: 1000);
      rethrow;
    }
  }

  /// DELETE request with logging and timeout
  Future<http.Response> delete(
    String path, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final url = '$baseUrl$path';
    final requestHeaders = _getHeaders(additionalHeaders: headers);

    _logRequest('DELETE', url, requestHeaders);

    try {
      final response = await http
          .delete(
            Uri.parse(url),
            headers: requestHeaders,
          )
          .timeout(timeout ?? ApiConfig.requestTimeout);

      _logResponse('DELETE', url, response.statusCode, response.body);

      // Handle 401 automatically
      if (response.statusCode == 401 && _authProvider != null) {
        developer.log('❌ 401 Unauthorized - clearing auth',
          name: 'HttpClientService');
        await _authProvider!.clearAuth();
      }

      return response;
    } catch (e) {
      developer.log('❌ DELETE request failed: $e',
          name: 'HTTP_CLIENT', error: e, level: 1000);
      rethrow;
    }
  }

  /// PATCH request with logging and timeout
  Future<http.Response> patch(
    String path, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    final url = '$baseUrl$path';
    final requestHeaders = _getHeaders(additionalHeaders: headers);

    final bodyString = body != null ? jsonEncode(body) : null;
    _logRequest('PATCH', url, requestHeaders, body: bodyString);

    try {
      final response = await http
          .patch(
            Uri.parse(url),
            headers: requestHeaders,
            body: bodyString,
          )
          .timeout(timeout ?? ApiConfig.requestTimeout);

      _logResponse('PATCH', url, response.statusCode, response.body);

      // Handle 401 automatically
      if (response.statusCode == 401 && _authProvider != null) {
        developer.log('❌ 401 Unauthorized - clearing auth',
          name: 'HttpClientService');
        await _authProvider!.clearAuth();
      }

      return response;
    } catch (e) {
      developer.log('❌ PATCH request failed: $e',
          name: 'HTTP_CLIENT', error: e, level: 1000);
      rethrow;
    }
  }
}
