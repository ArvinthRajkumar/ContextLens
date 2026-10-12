import 'dart:async';
import 'dart:math';

import 'package:contextlens/core/connectivity.dart';
import 'package:contextlens/core/utils/validators.dart';
import 'package:contextlens/features/compose/compose_controller.dart';
import 'package:contextlens/features/compose/declaration.dart';
import 'package:contextlens/features/compose/video_inspector.dart';
import 'package:contextlens/features/report/mock_backend.dart';
import 'package:contextlens/features/upload/fake_upload_repository.dart';
import 'package:contextlens/features/upload/upload_controller.dart';
import 'package:contextlens/features/upload/upload_copy.dart';
import 'package:contextlens/features/upload/upload_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _mb = 1024 * 1024;

const _submission = ComposeSubmission(
  video: PickedVideo(
    path: '/cache/clip.mp4',
    name: 'clip.mp4',
    sizeBytes: 2 * _mb,
    container: VideoContainer.mp4,
    duration: Duration(seconds: 7),
    width: 1280,
    height: 720,
  ),
  declaration: DeclarationDraft(caption: 'Morning routine'),
);

void main() {
  group('helpers', () {
    test('smoothSpeed is an EMA with alpha 0.3', () {
      expect(smoothSpeed(null, 100), 100);
      expect(smoothSpeed(100, 200), closeTo(130, 1e-9));
    });

    test('retryDelay doubles from 1 s with up to 20% jitter', () {
      for (var attempt = 1; attempt <= 4; attempt++) {
        final base = 1000 * pow(2, attempt - 1);
        final delay = retryDelay(attempt).inMilliseconds;
        expect(delay, inInclusiveRange(base, base * 1.2));
      }
    });

    test('time left and speed read naturally', () {
      expect(formatTimeLeft(const Duration(seconds: 24)), 'about 24 s left');
      expect(
        formatTimeLeft(const Duration(milliseconds: 300)),
        'about 1 s left',
      );
      expect(formatTimeLeft(const Duration(seconds: 125)), 'about 3 min left');
      expect(formatSpeed(3.2 * _mb), '3.2 MB/s');
    });

    test('time left uses the smoothed speed', () {
      const state = UploadState(
        submission: _submission,
        phase: UploadPhase.uploading,
        sentBytes: _mb,
        totalBytes: 2 * _mb,
        bytesPerSecond: _mb / 4,
      );
      expect(state.timeLeft, const Duration(seconds: 4));
    });
  });

  group('UploadController', () {
    late MockBackend backend;
    late StreamController<bool> online;
    late bool failNext;

    setUp(() {
      backend = MockBackend(stageDuration: const Duration(milliseconds: 10));
      online = StreamController<bool>();
      failNext = false;
    });

    Future<ProviderContainer> start(WidgetTester tester) async {
      await tester.runAsync(backend.fixtures);
      final container = ProviderContainer(
        overrides: [
          isOnlineProvider.overrideWith((ref) => online.stream),
          uploadRepositoryProvider.overrideWithValue(
            FakeUploadRepository(
              backend: backend,
              bytesPerSecond: _mb,
              shouldFail: () => failNext,
              random: Random(7),
            ),
          ),
        ],
      );
      addTearDown(() {
        container.dispose();
        backend.dispose();
        unawaited(online.close());
      });
      container.listen(uploadControllerProvider, (_, _) {});
      online.add(true);
      await tester.pump();
      unawaited(
        container.read(uploadControllerProvider.notifier).start(_submission),
      );
      await tester.pump();
      return container;
    }

    UploadState state(ProviderContainer c) => c.read(uploadControllerProvider)!;

    testWidgets('uploads to the end and submits the check', (tester) async {
      final c = await start(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(state(c).phase, UploadPhase.uploading);
      expect(state(c).progress, inExclusiveRange(0.3, 0.7));
      expect(state(c).bytesPerSecond, isNotNull);

      await tester.pump(const Duration(seconds: 2));
      expect(state(c).phase, UploadPhase.done);
      expect(state(c).sentBytes, 2 * _mb);
      expect(state(c).jobId, startsWith('job_'));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('pause holds the offset and resume continues from it', (
      tester,
    ) async {
      final c = await start(tester);
      await tester.pump(const Duration(milliseconds: 600));
      c.read(uploadControllerProvider.notifier).pause();
      final held = state(c).sentBytes;
      expect(state(c).phase, UploadPhase.paused);

      await tester.pump(const Duration(seconds: 2));
      expect(state(c).sentBytes, held);

      unawaited(c.read(uploadControllerProvider.notifier).resume());
      await tester.pump(const Duration(milliseconds: 300));
      expect(state(c).sentBytes, greaterThan(held));
      await tester.pump(const Duration(seconds: 3));
      expect(state(c).phase, UploadPhase.done);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a transient failure retries with backoff and finishes', (
      tester,
    ) async {
      failNext = true;
      final c = await start(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(state(c).phase, UploadPhase.retrying);
      expect(state(c).failure, isA<UploadNetworkError>());
      expect(state(c).progress, inInclusiveRange(0.35, 0.5));

      await tester.pump(const Duration(milliseconds: 1300));
      expect(state(c).phase, UploadPhase.uploading);
      await tester.pump(const Duration(seconds: 3));
      expect(state(c).phase, UploadPhase.done);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('going offline pauses and coming back resumes', (tester) async {
      final c = await start(tester);
      await tester.pump(const Duration(milliseconds: 500));
      online.add(false);
      await tester.pump();
      expect(state(c).phase, UploadPhase.waitingForNetwork);
      final held = state(c).sentBytes;

      await tester.pump(const Duration(seconds: 2));
      expect(state(c).sentBytes, held);

      online.add(true);
      await tester.pump(const Duration(seconds: 3));
      expect(state(c).phase, UploadPhase.done);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('cancel discards the upload', (tester) async {
      final c = await start(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await c.read(uploadControllerProvider.notifier).cancel();
      expect(state(c).phase, UploadPhase.cancelled);
      await tester.pump(const Duration(seconds: 3));
      expect(state(c).phase, UploadPhase.cancelled);
    });
  });
}
