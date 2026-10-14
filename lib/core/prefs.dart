import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loaded once in main() and injected with an override.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override in ProviderScope'),
);

/// Keys of settings that no longer exist: the theme choice (the app is light
/// only) and the in-app Reduce motion switch (the system setting decides).
const _retiredKeys = ['appearance.themeMode', 'appearance.reduceMotion'];

void clearRetiredPrefs(SharedPreferences prefs) {
  for (final key in _retiredKeys) {
    if (prefs.containsKey(key)) unawaited(prefs.remove(key));
  }
}
