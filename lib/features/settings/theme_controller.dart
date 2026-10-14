import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loaded once in main() and injected with an override.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override in ProviderScope'),
);

@immutable
class AppearanceSettings {
  const AppearanceSettings({this.themeMode = ThemeMode.dark});

  final ThemeMode themeMode;

  AppearanceSettings copyWith({ThemeMode? themeMode}) {
    return AppearanceSettings(themeMode: themeMode ?? this.themeMode);
  }
}

class ThemeController extends Notifier<AppearanceSettings> {
  static const _themeKey = 'appearance.themeMode';
  // The in-app "Reduce motion" switch is gone; only the system setting
  // counts now. Clears the old stored choice.
  static const _legacyMotionKey = 'appearance.reduceMotion';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppearanceSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final storedMode = prefs.getString(_themeKey);
    if (prefs.containsKey(_legacyMotionKey)) {
      unawaited(prefs.remove(_legacyMotionKey));
    }
    return AppearanceSettings(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == storedMode,
        orElse: () => ThemeMode.dark,
      ),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(_themeKey, mode.name);
  }
}

final themeControllerProvider =
    NotifierProvider<ThemeController, AppearanceSettings>(ThemeController.new);
