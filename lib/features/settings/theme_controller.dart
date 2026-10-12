import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loaded once in main() and injected with an override.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override in ProviderScope'),
);

@immutable
class AppearanceSettings {
  const AppearanceSettings({
    this.themeMode = ThemeMode.dark,
    this.reduceMotion = false,
  });

  final ThemeMode themeMode;

  /// Forces reduced motion on top of the system setting.
  final bool reduceMotion;

  AppearanceSettings copyWith({ThemeMode? themeMode, bool? reduceMotion}) {
    return AppearanceSettings(
      themeMode: themeMode ?? this.themeMode,
      reduceMotion: reduceMotion ?? this.reduceMotion,
    );
  }
}

class ThemeController extends Notifier<AppearanceSettings> {
  static const _themeKey = 'appearance.themeMode';
  static const _motionKey = 'appearance.reduceMotion';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppearanceSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final storedMode = prefs.getString(_themeKey);
    return AppearanceSettings(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == storedMode,
        orElse: () => ThemeMode.dark,
      ),
      reduceMotion: prefs.getBool(_motionKey) ?? false,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(_themeKey, mode.name);
  }

  Future<void> setReduceMotion({required bool enabled}) async {
    state = state.copyWith(reduceMotion: enabled);
    await _prefs.setBool(_motionKey, enabled);
  }
}

final themeControllerProvider =
    NotifierProvider<ThemeController, AppearanceSettings>(ThemeController.new);
