import 'dart:convert';
import 'dart:io';

import 'package:contextlens/core/prefs.dart';
import 'package:contextlens/core/theme/app_theme.dart';
import 'package:contextlens/features/compose/compose_controller.dart';
import 'package:contextlens/features/compose/compose_page.dart';
import 'package:contextlens/features/compose/declaration.dart';
import 'package:contextlens/features/report/comparison.dart';
import 'package:contextlens/features/report/flag_card.dart';
import 'package:contextlens/features/report/flag_presentation.dart';
import 'package:contextlens/features/report/mock_backend.dart';
import 'package:contextlens/features/report/models.dart';
import 'package:contextlens/features/report/playback.dart';
import 'package:contextlens/features/report/report_page.dart';
import 'package:contextlens/features/report/transcript_diff.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_report_player.dart';

Job _fixture(String name) => Job.fromJson(
  jsonDecode(File('assets/mock/$name').readAsStringSync())
      as Map<String, dynamic>,
);

/// The report's list, not the detail page's or the timeline's. A function,
/// so each test evaluates a fresh finder.
Finder _reportList() => find
    .descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    )
    .first;

void main() {
  group('compareRuns', () {
    test('matches issues by fingerprint', () {
      final v1 = _fixture('report_v1.json');
      final v2 = _fixture('report_v2.json');
      final c = compareRuns(v1, v2);
      expect((c.resolved, c.remaining, c.newCount), (3, 1, 0));
      expect(c.previousJobId, v1.id);
    });

    test('counts new issues and ignores checked claims', () {
      final v1 = _fixture('report_v1.json');
      final finance = _fixture('report_finance.json');
      final c = compareRuns(v1, finance);
      expect(c.resolved, v1.issues.length);
      expect(c.newCount, finance.issues.length);
    });
  });

  late MockBackend backend;
  late List<FakeReportPlayer> players;

  Future<void> pumpRoute(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'debug.seedMockData': true});
    final prefs = await SharedPreferences.getInstance();
    backend = MockBackend();
    await tester.runAsync(backend.fixtures);
    addTearDown(backend.dispose);
    players = [];

    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox()),
        GoRoute(
          path: '/report/:id',
          builder: (_, s) => ReportPage(jobId: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/new',
          builder: (_, s) =>
              ComposePage(parentJobId: s.uri.queryParameters['parent']),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          mockBackendProvider.overrideWithValue(backend),
          reportPlayerFactoryProvider.overrideWithValue((source) {
            final player = FakeReportPlayer(source);
            players.add(player);
            return player;
          }),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders every category and fact label from the fixture', (
    tester,
  ) async {
    await pumpRoute(tester, '/report/job_demo_finance');

    expect(find.text('7 flags'), findsOneWidget);
    for (final category in FlagCategory.values) {
      if (category == FlagCategory.unknown) continue;
      expect(
        find.bySemanticsLabel(RegExp('^${category.label} flag at')),
        findsWidgets,
        reason: 'timeline marker for $category',
      );
    }
    for (final label in FactLabel.values) {
      if (label == FactLabel.unknown) continue;
      // Back to the top each time: the labels are not in list order.
      await tester.drag(_reportList(), const Offset(0, 4000));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(label.label),
        200,
        scrollable: _reportList(),
      );
      expect(find.text(label.label), findsWidgets, reason: '$label');
    }
    final claimsChecked = find.text('Claims checked', skipOffstage: false);
    await tester.ensureVisible(claimsChecked);
    await tester.pumpAndSettle();
    expect(find.text('Claims checked'), findsOneWidget);
    expect(players.single.source, isA<AssetPlayback>());
  });

  testWidgets('a marker seeks the video and selects its card', (tester) async {
    await pumpRoute(tester, '/report/job_demo_v1');

    await tester.tap(find.bySemanticsLabel(RegExp('^Claims flag at 0:15')));
    await tester.pumpAndSettle();

    expect(players.single.seeks.last, const Duration(milliseconds: 15400));
    final card = tester.widget<FlagCard>(
      find.ancestor(
        of: find.text('Supplement shown as treating diabetes'),
        matching: find.byType(FlagCard),
      ),
    );
    expect(card.selected, isTrue);
    expect(card.pulse, 1);
  });

  testWidgets('a card expands to evidence and opens its details', (
    tester,
  ) async {
    await pumpRoute(tester, '/report/job_demo_v1');

    final podcast = find.text(
      'Podcast clip is trimmed in a way that changes its meaning',
    );
    await tester.scrollUntilVisible(podcast, 200, scrollable: _reportList());
    await tester.ensureVisible(podcast);
    await tester.pumpAndSettle();
    await tester.tap(podcast);
    await tester.pumpAndSettle();
    expect(players.single.seeks.last, const Duration(milliseconds: 31000));
    expect(find.text('Suggested fix'), findsOneWidget);

    await tester.ensureVisible(find.text('Details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    final detail = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.byType(TranscriptDiffView),
      200,
      scrollable: detail,
    );
    expect(find.text('Clip compared with the original'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('The Chai Break podcast'),
      200,
      scrollable: detail,
    );
    await tester.drag(detail, const Offset(0, 4000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Watch this part'));
    await tester.pumpAndSettle();
    expect(players.single.playing, isTrue);
  });

  testWidgets('an uncertain flag is listed but not counted', (tester) async {
    await pumpRoute(tester, '/report/job_demo_finance');

    expect(find.text('7'), findsOneWidget);
    expect(find.text('7 flags'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('^Uncertain claims flag at 1:18')),
      findsOneWidget,
    );
    final heading = find.text('Needs a human look', skipOffstage: false);
    await tester.scrollUntilVisible(heading, 200, scrollable: _reportList());
    expect(heading, findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(UncertainPresentation.label),
      200,
      scrollable: _reportList(),
    );
    expect(find.text(UncertainPresentation.label), findsOneWidget);
  });

  testWidgets('a compliance flag shows its clause and the source passage', (
    tester,
  ) async {
    await pumpRoute(tester, '/report/job_demo_v1');

    expect(find.text('ASCI Influencer Guidelines, 1.1(b)'), findsOneWidget);
    expect(find.text('Self-regulatory'), findsOneWidget);
    expect(find.text('Drugs and Magic Remedies Act, s. 3(d)'), findsOneWidget);
    expect(find.text('Statutory'), findsOneWidget);

    final card = find.text('Brand deal without an Ad label');
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    final detail = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.text('From the source'),
      200,
      scrollable: detail,
    );
    expect(
      find.textContaining('a disclosure is needed even if'),
      findsOneWidget,
    );
  });

  testWidgets('a category chip brings its flags to the top and back', (
    tester,
  ) async {
    await pumpRoute(tester, '/report/job_demo_finance');
    List<String> order() => tester
        .widgetList<FlagCard>(find.byType(FlagCard, skipOffstage: false))
        .where((card) => card.flag.isIssue)
        .map((card) => card.flag.id)
        .toList();
    final initial = order();
    expect(initial.first, 'b1');

    final chip = find.bySemanticsLabel(RegExp('^3 fact check flags'));
    final disclosure = find.bySemanticsLabel(RegExp('^1 disclosure flag'));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pump(const Duration(milliseconds: 100));
    expect(order().take(3), ['b5', 'b6', 'b7']);
    expect(order().skip(3), ['b1', 'b2', 'b3', 'b4']);
    await tester.pumpAndSettle();

    await tester.ensureVisible(disclosure);
    await tester.pumpAndSettle();
    await tester.tap(disclosure);
    await tester.pumpAndSettle();
    expect(order().first, 'b1');
    expect(order()[1], 'b2');

    await tester.ensureVisible(disclosure);
    await tester.pumpAndSettle();
    await tester.tap(disclosure);
    await tester.pumpAndSettle();
    expect(order(), initial);
  });

  testWidgets('run 2 shows 3 of 4 resolved', (tester) async {
    await pumpRoute(tester, '/report/job_demo_v2');
    expect(find.text('3 of 4 issues resolved'), findsOneWidget);
    expect(find.text('See run 1'), findsOneWidget);
  });

  testWidgets('Fix and re-upload carries the declaration over', (tester) async {
    await pumpRoute(tester, '/report/job_demo_v1');
    await tester.tap(find.text('Fix and re-upload'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Checking a fix for'), findsOneWidget);
    expect(
      find.textContaining('3 supplements I take every morning'),
      findsWidgets,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ComposePage)),
    );
    final state = container.read(composeControllerProvider);
    expect(state.declaration.isPaid, isTrue);
    expect(state.declaration.brand, 'VitaBoost');
    expect(state.declaration.category, ContentCategory.health);
  });

  testWidgets('the transcript diff marks what the clip left out', (
    tester,
  ) async {
    final diff = _fixture('report_v1.json').flags
        .firstWhere((f) => f.diff != null)
        .diff!;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: TranscriptDiffView(diff: diff)),
      ),
    );
    expect(find.text('In your clip'), findsOneWidget);
    expect(find.text('Left out of your clip'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        RegExp(
          "Left out of your clip: if a blood test shows they're deficient",
        ),
      ),
      findsOneWidget,
    );
  });
}
