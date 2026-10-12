import 'package:contextlens/core/theme/app_theme.dart';
import 'package:contextlens/features/settings/theme_controller.dart';
import 'package:contextlens/features/splash/splash_gate.dart';
import 'package:contextlens/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ContextLensApp extends ConsumerWidget {
  const ContextLensApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(themeControllerProvider);

    return MaterialApp.router(
      title: 'ContextLens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      routerConfig: router,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        // Folds the in-app override into disableAnimations so every widget
        // (and Motion.of) honors one signal.
        return MediaQuery(
          data: settings.reduceMotion
              ? media.copyWith(disableAnimations: true)
              : media,
          child: SplashGate(child: child!),
        );
      },
    );
  }
}
