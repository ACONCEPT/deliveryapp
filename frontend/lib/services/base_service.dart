import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'http_client_service.dart';

/// Abstract base class for all API services providing common functionality
/// for HTTP operations, response parsing, and error handling.
///
/// Example usage:
/// ```dart
/// class MyService extends BaseService {
///   @override
///   String get serviceName => 'MyService';
///
///   Future<List<MyModel>> getItems(String token) async {
///     return getList<MyModel>(
///       '/api/my-items',
///       (json) => MyModel.fromJson(json),
///       token: token,
///     );
///   }
/// }
/// ```
abstract class BaseService {
  final HttpClientService httpClient = HttpClientService();

  /// Service name used for logging. Must be overridden by subclasses.
  String get serviceName;

  /// Helper to create Authorization header with Bearer token
  Map<String, String> authHeaders(String token) {
    return {'Authorization': 'Bearer $token'};
  }

  /// Parse a list response from the API. Handles multiple response formats:
  /// - Direct array: `[{...}, {...}]`
  /// - Wrapped array: `{"items": [{...}, {...}]}`
  /// - Null/missing array: Returns empty list
  ///
  /// [json] The decoded JSON response
  /// [key] The key to extract the list from (e.g., 'addresses', 'items')
  /// [fromJson] Factory function to convert JSON map to model instance
  List<T> parseListResponse<T>(
    Map<String, dynamic> json,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    try {
      final data = json[key];

      if (data == null) {
        developer.log('$key field is null, returning empty list',
            name: serviceName);
        return [];
      }

      if (data is! List) {
        developer.log('$key field is not a List: $data', name: serviceName);
        return [];
      }

      return data
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      developer.log(
        'Error parsing list response for key: $key',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Parse an object response from the API. Handles wrapped responses:
  /// - `{"address": {...}}`
  /// - `{"item": {...}}`
  ///
  /// [json] The decoded JSON response
  /// [key] The key to extract the object from (e.g., 'address', 'item')
  /// [fromJson] Factory function to convert JSON map to model instance
  T parseObjectResponse<T>(
    Map<String, dynamic> json,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    try {
      final data = json[key];
      if (data == null) {
        throw Exception('$key field is missing from response');
      }
      return fromJson(data as Map<String, dynamic>);
    } catch (e, stackTrace) {
      developer.log(
        'Error parsing object response for key: $key',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Execute a void operation (e.g., delete, set-default) that doesn't return data
  ///
  /// [operation] The async function to execute
  /// [operationName] Name for logging purposes
  Future<void> executeVoidOperation(
    Future<http.Response> Function() operation,
    String operationName,
  ) async {
    try {
      final response = await operation();

      if (response.statusCode != 200) {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Failed to $operationName');
      }

      developer.log('$operationName completed successfully', name: serviceName);
    } catch (e, stackTrace) {
      developer.log(
        'Error in $operationName',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Standard GET request for fetching a list of items
  ///
  /// [path] API endpoint path
  /// [responseKey] Key to extract list from response (e.g., 'addresses')
  /// [fromJson] Factory function to convert JSON to model
  /// [token] Optional Bearer token for authentication
  Future<List<T>> getList<T>(
    String path,
    String responseKey,
    T Function(Map<String, dynamic>) fromJson, {
    String? token,
  }) async {
    try {
      final headers = token != null ? authHeaders(token) : null;
      final response = await httpClient.get(path, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return parseListResponse<T>(data, responseKey, fromJson);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to fetch list');
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error in getList for path: $path',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Standard GET request for fetching a single object
  ///
  /// [path] API endpoint path
  /// [responseKey] Key to extract object from response (e.g., 'address')
  /// [fromJson] Factory function to convert JSON to model
  /// [token] Optional Bearer token for authentication
  Future<T> getObject<T>(
    String path,
    String responseKey,
    T Function(Map<String, dynamic>) fromJson, {
    String? token,
  }) async {
    try {
      final headers = token != null ? authHeaders(token) : null;
      final response = await httpClient.get(path, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return parseObjectResponse<T>(data, responseKey, fromJson);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to fetch object');
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error in getObject for path: $path',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Standard POST request for creating a resource
  ///
  /// [path] API endpoint path
  /// [responseKey] Key to extract created object from response
  /// [body] Request body (will be JSON encoded)
  /// [fromJson] Factory function to convert JSON to model
  /// [token] Optional Bearer token for authentication
  Future<T> postObject<T>(
    String path,
    String responseKey,
    Map<String, dynamic> body,
    T Function(Map<String, dynamic>) fromJson, {
    String? token,
  }) async {
    try {
      final headers = token != null ? authHeaders(token) : null;
      final response = await httpClient.post(
        path,
        headers: headers,
        body: body,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return parseObjectResponse<T>(data, responseKey, fromJson);
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Failed to create resource');
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error in postObject for path: $path',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Standard PUT request for updating a resource
  ///
  /// [path] API endpoint path
  /// [responseKey] Key to extract updated object from response
  /// [body] Request body (will be JSON encoded)
  /// [fromJson] Factory function to convert JSON to model
  /// [token] Optional Bearer token for authentication
  Future<T> putObject<T>(
    String path,
    String responseKey,
    Map<String, dynamic> body,
    T Function(Map<String, dynamic>) fromJson, {
    String? token,
  }) async {
    try {
      final headers = token != null ? authHeaders(token) : null;
      final response = await httpClient.put(
        path,
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return parseObjectResponse<T>(data, responseKey, fromJson);
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Failed to update resource');
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error in putObject for path: $path',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Standard DELETE request for deleting a resource
  ///
  /// [path] API endpoint path
  /// [token] Optional Bearer token for authentication
  Future<void> deleteResource(
    String path, {
    String? token,
  }) async {
    await executeVoidOperation(
      () async {
        final headers = token != null ? authHeaders(token) : null;
        return await httpClient.delete(path, headers: headers);
      },
      'delete resource at $path',
    );
  }
}
