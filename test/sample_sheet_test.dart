import 'dart:async';

import 'package:contextlens/core/theme/app_theme.dart';
import 'package:contextlens/features/compose/compose_controller.dart';
import 'package:contextlens/features/compose/compose_page.dart';
import 'package:contextlens/features/drafts/draft.dart';
import 'package:contextlens/features/drafts/draft_repository.dart';
import 'package:contextlens/features/home/check_video_card.dart';
import 'package:contextlens/features/samples/sample_repository.dart';
import 'package:contextlens/features/samples/sample_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        sampleRepositoryProvider.overrideWithValue(
          const FakeSampleRepository(),
        ),
        draftRepositoryProvider.overrideWithValue(MemoryDraftRepository()),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: Padding(padding: EdgeInsets.all(16), child: CheckVideoCard()),
          ),
          routes: [
            GoRoute(path: 'new', builder: (_, _) => const ComposePage()),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    return container;
  }

  testWidgets('the gallery lists each sample with its hint and language', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Try a sample video'));
    await tester.pumpAndSettle();

    expect(find.byType(SampleSheet), findsOneWidget);
    for (final sample in fakeSamples) {
      expect(find.text(sample.title), findsOneWidget);
      expect(find.text(sample.hint), findsOneWidget);
    }
    expect(find.text('English'), findsNWidgets(fakeSamples.length));
    expect(find.text('0:34'), findsOneWidget);
  });

  testWidgets('choosing a sample opens New check filled in and ready', (
    tester,
  ) async {
    final container = await pump(tester);
    await tester.tap(find.text('Try a sample video'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Clip that drops the doctor's warning"));
    await tester.pumpAndSettle();

    expect(find.byType(SampleSheet), findsNothing);
    expect(find.byType(ComposePage), findsOneWidget);
    final state = container.read(composeControllerProvider);
    final video = state.video;
    expect(video, isA<VideoReady>());
    expect((video as VideoReady).video.sampleId, 'vitamind');
    expect(state.declaration.caption, startsWith('Doctor says'));
    expect(state.declaration.clips.single.sampleSourceId, 'vitamind_source');
    expect(state.canSubmit, isTrue, reason: state.blocker);
    // The form shows it, and stays editable.
    expect(find.textContaining('Doctor says everyone needs'), findsOneWidget);
    expect(find.text('Morning Health Chat interview'), findsOneWidget);
  });

  testWidgets('New check offers samples too', (tester) async {
    final container = await pump(tester);
    container.read(composeControllerProvider.notifier).reset();
    unawaited(
      GoRouter.of(tester.element(find.byType(CheckVideoCard))).push('/new'),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Try a sample video'));
    await tester.tap(find.text('Try a sample video'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gifted supplement with health claims'));
    await tester.pumpAndSettle();

    final state = container.read(composeControllerProvider);
    expect((state.video as VideoReady).video.sampleId, 'glucoleaf');
    expect(state.declaration.brand, 'GlucoLeaf');
    expect(state.declaration.isPaid, isTrue);
  });

  test('a sample draft keeps the sample id, not a copy of the video', () async {
    final sample = fakeSamples.first;
    final draft = Draft(
      id: 'd1',
      updatedAt: DateTime.utc(2026, 10, 15),
      declaration: sample.toDraft(),
      video: sample.toVideo(),
    );
    final back = Draft.fromJson(draft.toJson().cast<String, Object?>());
    expect(back.video!.sampleId, 'glucoleaf');
    expect(back.declaration.brand, 'GlucoLeaf');
  });
}
