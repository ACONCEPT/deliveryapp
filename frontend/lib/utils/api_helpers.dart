import 'dart:developer' as developer;

/// API helper utilities for consistent error handling and logging
class ApiHelpers {
  /// Wraps an API call with standardized error handling and logging
  ///
  /// [methodName] - Name of the method being called (for logging)
  /// [apiCall] - The async function to execute
  /// [loggerName] - Name to use in log messages (typically the service name)
  ///
  /// Automatically logs errors with stack traces and rethrows them.
  /// This eliminates the need for repeated try-catch blocks in every service method.
  static Future<T> handleApiCall<T>(
    String methodName,
    Future<T> Function() apiCall, {
    String loggerName = 'ApiService',
  }) async {
    try {
      return await apiCall();
    } catch (e, stackTrace) {
      developer.log(
        'Error in $methodName',
        name: loggerName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Wraps a synchronous operation with error handling
  ///
  /// [methodName] - Name of the method being called (for logging)
  /// [operation] - The function to execute
  /// [loggerName] - Name to use in log messages
  static T handleOperation<T>(
    String methodName,
    T Function() operation, {
    String loggerName = 'ApiService',
  }) {
    try {
      return operation();
    } catch (e, stackTrace) {
      developer.log(
        'Error in $methodName',
        name: loggerName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Executes an API call with retry logic for failed requests
  ///
  /// [methodName] - Name of the method being called (for logging)
  /// [apiCall] - The async function to execute
  /// [maxRetries] - Maximum number of retry attempts (default: 3)
  /// [retryDelay] - Base delay between retries (uses exponential backoff)
  /// [loggerName] - Name to use in log messages
  ///
  /// Retries with exponential backoff: 1s, 2s, 4s, etc.
  static Future<T> handleApiCallWithRetry<T>(
    String methodName,
    Future<T> Function() apiCall, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
    String loggerName = 'ApiService',
  }) async {
    int attempt = 0;

    while (true) {
      try {
        return await apiCall();
      } catch (e, stackTrace) {
        attempt++;

        if (attempt >= maxRetries) {
          developer.log(
            'Error in $methodName after $maxRetries attempts',
            name: loggerName,
            error: e,
            stackTrace: stackTrace,
          );
          rethrow;
        }

        final delay = retryDelay * (1 << (attempt - 1)); // Exponential backoff
        developer.log(
          'Error in $methodName (attempt $attempt/$maxRetries), retrying in ${delay.inSeconds}s',
          name: loggerName,
          error: e,
        );

        await Future.delayed(delay);
      }
    }
  }
}
