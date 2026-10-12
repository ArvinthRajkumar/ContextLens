import 'package:contextlens/app.dart';
import 'package:contextlens/core/config.dart';
import 'package:contextlens/features/settings/theme_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  // Both are compile-time consts, so release builds tree-shake the driver out.
  if (AppConfig.enableFlutterDriver && !kReleaseMode) {
    enableFlutterDriverExtension();
  }
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('Uncaught: $error\n$stack');
    }
    return true;
  };

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const ContextLensApp(),
    ),
  );
}
