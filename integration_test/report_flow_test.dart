import 'dart:math';

import 'package:contextlens/app.dart';
import 'package:contextlens/core/connectivity.dart';
import 'package:contextlens/core/prefs.dart';
import 'package:contextlens/core/utils/validators.dart';
import 'package:contextlens/features/compose/video_inspector.dart';
import 'package:contextlens/features/compose/video_source.dart';
import 'package:contextlens/features/report/mock_backend.dart';
import 'package:contextlens/features/splash/splash_page.dart';
import 'package:contextlens/features/upload/fake_upload_repository.dart';
import 'package:contextlens/features/upload/upload_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// End to end on the mock backend:
// pick -> declare -> upload -> success -> stages -> report -> re-upload ->
// comparison. Run: flutter test integration_test/report_flow_test.dart -d <device>

class _FixtureSource implements VideoSource {
  static const file = PickedFile(
    path: '/cache/fixture.mp4',
    name: 'morning-routine.mp4',
    mimeType: 'video/mp4',
  );

  @override
  Future<PickedFile?> pickFromGallery() async => file;

  @override
  Future<PickedFile?> pickFromFiles() async => file;
}

class _FixtureInspector implements VideoInspector {
  @override
  Future<Inspection> inspect(
    String path, {
    required String name,
    String? mimeType,
  }) async => InspectionPassed(
    PickedVideo(
      path: path,
      name: name,
      sizeBytes: 3 * 1024 * 1024,
      container: VideoContainer.mp4,
      duration: const Duration(seconds: 58),
      width: 1080,
      height: 1920,
    ),
  );
}

/// Pumps frames until [finder] shows up. The stage stepper pulses forever,
/// so pumpAndSettle can't be used on the Run screen.
Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
  bool absent = false,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty != absent) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a check, a fix and the comparison', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final backend = MockBackend(
      stageDuration: const Duration(milliseconds: 500),
    );
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          mockBackendProvider.overrideWithValue(backend),
          isOnlineProvider.overrideWith((ref) => Stream.value(true)),
          videoSourceProvider.overrideWithValue(_FixtureSource()),
          videoInspectorProvider.overrideWithValue(_FixtureInspector()),
          uploadRepositoryProvider.overrideWithValue(
            FakeUploadRepository(
              backend: backend,
              bytesPerSecond: 6 * 1024 * 1024,
              shouldFail: () => false,
              random: Random(3),
            ),
          ),
        ],
        child: const ContextLensApp(),
      ),
    );
    await _waitFor(tester, find.text('Check a video'));
    // The intro covers Home until it hands off.
    await _waitFor(tester, find.byType(SplashPage), absent: true);

    // First check.
    await tester.tap(find.text('Check a video'));
    await _waitFor(tester, find.text('Choose from gallery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from gallery'));
    await _waitFor(tester, find.text('morning-routine.mp4'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Caption'),
      '3 supplements I take every morning',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Run check'));

    await _waitFor(tester, find.text('Uploading'));
    await _waitFor(tester, find.text('Reading your video'));
    await _waitFor(
      tester,
      find.text('4 flags'),
      timeout: const Duration(seconds: 40),
    );
    await tester.pumpAndSettle();
    expect(find.text('issues to fix'), findsOneWidget);

    // Fix and re-upload: the declaration carries over.
    await tester.tap(find.text('Fix and re-upload'));
    await _waitFor(tester, find.textContaining('Checking a fix for'));
    await tester.pumpAndSettle();
    expect(find.text('3 supplements I take every morning'), findsWidgets);
    await tester.tap(find.text('Choose from gallery'));
    await _waitFor(tester, find.text('morning-routine.mp4'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Run check'));

    await _waitFor(
      tester,
      find.text('3 of 4 issues resolved'),
      timeout: const Duration(seconds: 40),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 flag'), findsOneWidget);
    expect(find.text('See run 1'), findsOneWidget);
  });
}
