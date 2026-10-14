import 'package:contextlens/core/theme/app_theme.dart';
import 'package:contextlens/features/push/push_service.dart';
import 'package:contextlens/features/settings/theme_controller.dart';
import 'package:contextlens/features/share/share_intake.dart';
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
    ref
      ..watch(shareIntakeProvider)
      ..watch(pushServiceProvider);

    return MaterialApp.router(
      title: 'ContextLens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      routerConfig: router,
      // The system "remove animations" setting reaches every widget (and
      // Motion.of) through MediaQuery.disableAnimations.
      builder: (context, child) => SplashGate(child: child!),
    );
  }
}
