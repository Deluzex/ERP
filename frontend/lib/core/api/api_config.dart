class ApiConfig {
  ApiConfig._();

  /// Base URL of the NestJS ERP backend
  /// In development, Flutter web or desktop targets http://localhost:3000/api/v1
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 15);
}
