import 'package:contextlens/features/gallery/gallery_page.dart';
import 'package:contextlens/features/home/home_page.dart';
import 'package:contextlens/features/settings/settings_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      if (kDebugMode)
        GoRoute(
          path: '/gallery',
          builder: (context, state) => const GalleryPage(),
        ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
