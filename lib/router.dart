import 'package:contextlens/core/theme/transitions.dart';
import 'package:contextlens/features/compose/compose_page.dart';
import 'package:contextlens/features/gallery/gallery_page.dart';
import 'package:contextlens/features/home/home_page.dart';
import 'package:contextlens/features/report/report_page.dart';
import 'package:contextlens/features/run/run_page.dart';
import 'package:contextlens/features/settings/settings_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Everything nests under Home so `go` to any screen leaves Home beneath it.
// The splash is an overlay (SplashGate), not a route, so Home builds while
// the intro plays and deep links skip nothing.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomePage(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) =>
                ComposePage(parentJobId: state.uri.queryParameters['parent']),
          ),
          GoRoute(
            path: 'run/:jobId',
            builder: (context, state) =>
                RunPage(jobId: state.pathParameters['jobId']!),
          ),
          GoRoute(
            path: 'report/:jobId',
            pageBuilder: (context, state) => fadeThroughPage(
              key: state.pageKey,
              child: ReportPage(jobId: state.pathParameters['jobId']!),
            ),
          ),
          GoRoute(
            path: 'settings',
            pageBuilder: (context, state) => fadeThroughPage(
              key: state.pageKey,
              child: const SettingsPage(),
            ),
          ),
          if (kDebugMode)
            GoRoute(
              path: 'gallery',
              builder: (context, state) => const GalleryPage(),
            ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
