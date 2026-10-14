import 'package:contextlens/core/theme/app_theme.dart';
import 'package:contextlens/features/report/flag_timeline.dart';
import 'package:contextlens/features/report/models.dart';
import 'package:contextlens/features/report/playback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Flag _flag(String id, int startMs, {bool uncertain = false}) => Flag(
  id: id,
  fingerprint: id,
  category: FlagCategory.claims,
  startMs: startMs,
  endMs: startMs + 1000,
  title: id,
  evidence: 'e',
  suggestedFix: 'f',
  severity: Severity.high,
  uncertain: uncertain,
);

void main() {
  late List<Duration> seeks;
  late List<String> selected;
  final playback = ValueNotifier(
    const PlaybackState(duration: Duration(seconds: 40), isReady: true),
  );

  Future<void> pump(WidgetTester tester, List<Flag> flags) async {
    seeks = [];
    selected = [];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: FlagTimeline(
                flags: flags,
                durationMs: 40000,
                playback: playback,
                selectedId: null,
                onSelect: (flag) => selected.add(flag.id),
                onSeek: seeks.add,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Rect track(WidgetTester tester) =>
      tester.getRect(find.byType(CustomPaint).last);

  testWidgets('tapping the bar seeks to that point', (tester) async {
    await pump(tester, [_flag('a', 36000)]);
    final rect = track(tester);
    await tester.tapAt(Offset(rect.left + rect.width / 4, rect.center.dy));
    await tester.pump();

    expect(seeks, hasLength(1));
    expect(seeks.single.inMilliseconds, closeTo(10000, 400));
    expect(selected, isEmpty);
  });

  testWidgets('dragging shows the time and seeks where it ends', (
    tester,
  ) async {
    await pump(tester, const []);
    final rect = track(tester);
    final gesture = await tester.startGesture(
      Offset(rect.left + 10, rect.center.dy),
    );
    await gesture.moveBy(const Offset(40, 0));
    await gesture.moveTo(Offset(rect.left + rect.width / 2, rect.center.dy));
    await tester.pump();
    expect(find.text('0:20'), findsOneWidget, reason: 'the time bubble');
    expect(seeks, isEmpty, reason: 'no seek until the finger lifts');

    await gesture.up();
    await tester.pump();
    expect(seeks.single.inMilliseconds, closeTo(20000, 400));
    expect(find.text('0:20'), findsNothing);
  });

  testWidgets('tapping a tick selects its flag instead of seeking', (
    tester,
  ) async {
    await pump(tester, [_flag('a', 10000), _flag('b', 30000, uncertain: true)]);
    final rect = track(tester);
    await tester.tapAt(Offset(rect.left + rect.width * 0.75, rect.center.dy));
    await tester.pump();

    expect(selected, ['b']);
    expect(seeks, isEmpty);
    expect(
      find.bySemanticsLabel(RegExp('^Uncertain claims flag at 0:30')),
      findsOneWidget,
    );
  });

  testWidgets('shows position and length on the right', (tester) async {
    playback.value = const PlaybackState(
      position: Duration(seconds: 7),
      duration: Duration(seconds: 40),
      isReady: true,
    );
    await pump(tester, const []);
    expect(find.text('0:07 / 0:40'), findsOneWidget);
  });
}
