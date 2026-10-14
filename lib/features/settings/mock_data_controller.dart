import 'package:contextlens/core/config.dart';
import 'package:contextlens/core/prefs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether mock mode serves seeded history. Defaults to the MOCK_SEED
/// dart-define and can be flipped from the debug section in Settings.
class MockDataController extends Notifier<bool> {
  static const _key = 'debug.seedMockData';

  @override
  bool build() {
    return ref.watch(sharedPreferencesProvider).getBool(_key) ??
        AppConfig.seedMockData;
  }

  Future<void> setSeeded({required bool seeded}) async {
    state = seeded;
    await ref.read(sharedPreferencesProvider).setBool(_key, seeded);
  }
}

final mockDataControllerProvider = NotifierProvider<MockDataController, bool>(
  MockDataController.new,
);
