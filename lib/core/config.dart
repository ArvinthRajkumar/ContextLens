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

  /// Simulated upload speed in mock mode, in bytes per second. Lower it to
  /// watch a small file upload, for example MOCK_UPLOAD_BPS=300000.
  static const int mockUploadBytesPerSecond = int.fromEnvironment(
    'MOCK_UPLOAD_BPS',
    defaultValue: 4 * 1024 * 1024,
  );

  /// Total time the mock backend spends on the five processing stages.
  static const int mockStageSeconds = int.fromEnvironment(
    'MOCK_STAGE_SECONDS',
    defaultValue: 25,
  );

  static const bool enableFlutterDriver = bool.fromEnvironment(
    'ENABLE_FLUTTER_DRIVER',
  );

  static BackendMode get backend =>
      _backend == 'real' ? BackendMode.real : BackendMode.mock;

  static bool get isMock => backend == BackendMode.mock;
}
