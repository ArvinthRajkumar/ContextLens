import 'dart:math';

import 'package:contextlens/core/connectivity.dart';
import 'package:contextlens/core/theme/app_theme.dart';
import 'package:contextlens/core/utils/validators.dart';
import 'package:contextlens/features/compose/compose_controller.dart';
import 'package:contextlens/features/compose/declaration.dart';
import 'package:contextlens/features/compose/video_inspector.dart';
import 'package:contextlens/features/report/mock_backend.dart';
import 'package:contextlens/features/run/lens_orbit.dart';
import 'package:contextlens/features/run/processing_view.dart';
import 'package:contextlens/features/run/run_page.dart';
import 'package:contextlens/features/run/success_burst.dart';
import 'package:contextlens/features/settings/theme_controller.dart';
import 'package:contextlens/features/upload/fake_upload_repository.dart';
import 'package:contextlens/features/upload/upload_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _submission = ComposeSubmission(
  video: PickedVideo(
    path: '/cache/clip.mp4',
    name: 'clip.mp4',
    sizeBytes: 200 * 1024,
    container: VideoContainer.mp4,
    duration: Duration(seconds: 7),
    width: 1280,
    height: 720,
  ),
  declaration: DeclarationDraft(caption: 'Morning routine'),
);

void main() {
  testWidgets('upload starts, then the burst plays before the stages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final backend = MockBackend(stageDuration: const Duration(seconds: 2));
    await tester.runAsync(backend.fixtures);
    addTearDown(backend.dispose);

    final router = GoRouter(
      initialLocation: '/run/$pendingRunId',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox()),
        GoRoute(
          path: '/run/:id',
          builder: (_, state) => RunPage(jobId: state.pathParameters['id']!),
        ),
        GoRoute(path: '/report/:id', builder: (_, _) => const Text('report')),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isOnlineProvider.overrideWith((ref) => Stream.value(true)),
        mockBackendProvider.overrideWithValue(backend),
        uploadRepositoryProvider.overrideWithValue(
          FakeUploadRepository(
            backend: backend,
            bytesPerSecond: 1024 * 1024,
            shouldFail: () => false,
            random: Random(1),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(pendingSubmissionProvider.notifier).set(_submission);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      ),
    );
    await tester.pump();
    expect(find.text('Uploading'), findsWidgets);

    // 200 KB at 1 MB/s finishes in well under a second.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SuccessBurst), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Uploading'),
      ),
      findsOneWidget,
      reason: 'the title stays Uploading until the disc lands',
    );

    // Stages stay hidden until the disc flies in.
    final stepper = find.byType(ProcessingView);
    if (stepper.evaluate().isNotEmpty) {
      final opacity = tester.widget<Opacity>(
        find.ancestor(of: stepper, matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, lessThan(0.05));
    }

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SuccessBurst), findsNothing);
    expect(find.byType(ProcessingView), findsOneWidget);
    expect(find.byType(LensOrbit), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Checking')),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 12));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('report'), findsOneWidget);
  });
}
