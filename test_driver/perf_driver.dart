import 'package:integration_test/integration_test_driver.dart';

/// Writes each test's reported performance data to `build/KEY_perf.json`.
Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) return;
    for (final entry in data.entries) {
      await writeResponseData(
        entry.value as Map<String, dynamic>,
        testOutputFilename: '${entry.key}_perf',
      );
    }
  },
);
