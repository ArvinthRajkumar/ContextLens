import 'package:contextlens/core/theme/app_theme.dart';
import 'package:contextlens/core/utils/validators.dart';
import 'package:contextlens/features/compose/compose_controller.dart';
import 'package:contextlens/features/compose/compose_page.dart';
import 'package:contextlens/features/compose/video_inspector.dart';
import 'package:contextlens/features/compose/video_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSource implements VideoSource {
  PickedFile? next;

  @override
  Future<PickedFile?> pickFromGallery() async => next;

  @override
  Future<PickedFile?> pickFromFiles() async => next;
}

class _FakeInspector implements VideoInspector {
  Inspection result = const InspectionPassed(
    PickedVideo(
      path: '/cache/clip.mp4',
      name: 'clip.mp4',
      sizeBytes: 25 * 1024 * 1024,
      container: VideoContainer.mp4,
      duration: Duration(seconds: 58),
      width: 1080,
      height: 1920,
    ),
  );

  @override
  Future<Inspection> inspect(
    String path, {
    required String name,
    String? mimeType,
  }) async => result;
}

void main() {
  late _FakeSource source;
  late _FakeInspector inspector;

  setUp(() {
    source = _FakeSource()
      ..next = const PickedFile(path: '/cache/clip.mp4', name: 'clip.mp4');
    inspector = _FakeInspector();
  });

  Future<void> pumpCompose(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoSourceProvider.overrideWithValue(source),
          videoInspectorProvider.overrideWithValue(inspector),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const ComposePage()),
      ),
    );
  }

  FilledButton runCheck(WidgetTester tester) => tester.widget<FilledButton>(
    find.ancestor(
      of: find.text('Run check'),
      matching: find.byType(FilledButton),
    ),
  );

  testWidgets('Run check stays disabled until video and caption are valid', (
    tester,
  ) async {
    await pumpCompose(tester);
    expect(runCheck(tester).onPressed, isNull);
    expect(find.text('Pick a video to continue'), findsOneWidget);

    await tester.tap(find.text('Choose from gallery'));
    await tester.pumpAndSettle();
    expect(find.text('clip.mp4'), findsOneWidget);
    expect(find.text('Add a caption'), findsOneWidget); // blocker hint
    expect(runCheck(tester).onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Caption'),
      'My routine',
    );
    await tester.pump();
    expect(runCheck(tester).onPressed, isNotNull);
  });

  testWidgets('field errors appear on leaving the field, not while typing', (
    tester,
  ) async {
    await pumpCompose(tester);
    await tester.tap(find.text('Paid or collab?'));
    await tester.pumpAndSettle();

    final brand = find.widgetWithText(TextFormField, 'Brand or partner');
    await tester.enterText(brand, 'V');
    await tester.pump();
    expect(find.text('That name looks too short'), findsNothing);

    // Moving focus to the caption validates the brand field.
    await tester.tap(find.widgetWithText(TextFormField, 'Caption'));
    await tester.pump();
    expect(find.text('That name looks too short'), findsOneWidget);
  });

  testWidgets('each video problem is shown inline on the card', (tester) async {
    const cases = <VideoProblem, String>{
      VideoTooLarge(600 * 1024 * 1024): 'File too large',
      VideoUnsupported(): 'Unsupported format',
      VideoTooShort(): 'Video too short',
      VideoTooLong(): 'Video too long',
      VideoUnreadable(): "Can't open this file",
      VideoDecodeTimeout(): 'Took too long to read',
    };
    await pumpCompose(tester);

    for (final MapEntry(key: problem, value: title) in cases.entries) {
      inspector.result = InspectionFailed(problem);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ComposePage)),
      );
      await container
          .read(composeControllerProvider.notifier)
          .pickFromGallery();
      await tester.pump();
      expect(find.text(title), findsOneWidget, reason: '$problem');
      if (problem is VideoTooLarge) {
        expect(
          find.text('This video is 600 MB. The limit is 500 MB.'),
          findsOneWidget,
        );
      }
      expect(find.text('Choose another'), findsOneWidget);
      expect(
        find.text('Try again'),
        problem is VideoDecodeTimeout ? findsOneWidget : findsNothing,
      );
      expect(runCheck(tester).onPressed, isNull);
    }
  });

  testWidgets('a borrowed clip needs a label and a link or file', (
    tester,
  ) async {
    await pumpCompose(tester);
    await tester.tap(find.text('Choose from gallery'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Caption'),
      'My routine',
    );
    await tester.tap(find.text('Add clip'));
    await tester.pumpAndSettle();

    expect(find.text('Add a short label'), findsOneWidget); // blocker hint
    await tester.enterText(
      find.widgetWithText(TextFormField, 'What is it?'),
      'Podcast',
    );
    await tester.pump();
    expect(find.text('Add a link or attach the clip'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Link to the original'),
      'https://example.com/212',
    );
    await tester.pump();
    expect(runCheck(tester).onPressed, isNotNull);
  });

  testWidgets('a numeric gallery pick shows a readable name', (tester) async {
    source.next = const PickedFile(path: '/cache/36.mp4', name: '36.mp4');
    await pumpCompose(tester);
    await tester.tap(find.text('Choose from gallery'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Video from gallery, '), findsOneWidget);
    expect(find.text('36.mp4'), findsNothing);
  });
}
