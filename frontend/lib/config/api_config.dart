/// API Configuration
/// Centralizes all API-related configuration including base URLs and endpoints
class ApiConfig {
  /// Base URL for the API server
  /// Can be overridden via environment variable API_BASE_URL
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// API version prefix
  static const String apiPrefix = '/api';

  /// Full base URL with API prefix
  static String get fullBaseUrl => '$baseUrl$apiPrefix';

  /// API Endpoints
  static const String login = '/auth/login';
  static const String addresses = '/addresses';
  static const String restaurants = '/restaurants';
  static const String menu = '/menu';
  static const String menuItems = '/menu-items';
  static const String orders = '/orders';
  static const String approvals = '/approvals';

  /// HTTP request timeout duration
  static const Duration requestTimeout = Duration(seconds: 30);

  /// Maximum number of retry attempts for failed requests
  static const int maxRetries = 3;

  /// Retry delay multiplier for exponential backoff
  static const Duration retryBaseDelay = Duration(seconds: 1);
}
