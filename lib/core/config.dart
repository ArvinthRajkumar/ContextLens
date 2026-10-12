enum BackendMode { mock, real }

/// Compile-time configuration passed with --dart-define.
abstract final class AppConfig {
  static const String _backend = String.fromEnvironment(
    'BACKEND',
    defaultValue: 'mock',
  );

  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Injects one transient upload failure in mock mode.
  static const bool mockFail = String.fromEnvironment('MOCK_FAIL') == '1';

  /// Starts mock mode with seeded history instead of an empty account.
  static const bool seedMockData = String.fromEnvironment('MOCK_SEED') == '1';

  static const bool enableFlutterDriver = bool.fromEnvironment(
    'ENABLE_FLUTTER_DRIVER',
  );

  static BackendMode get backend =>
      _backend == 'real' ? BackendMode.real : BackendMode.mock;

  static bool get isMock => backend == BackendMode.mock;
}
