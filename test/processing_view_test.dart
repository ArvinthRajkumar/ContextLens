import 'package:contextlens/core/theme/app_theme.dart';
import 'package:contextlens/features/report/models.dart';
import 'package:contextlens/features/run/lens_orbit.dart';
import 'package:contextlens/features/run/processing_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _start = DateTime.now();

Job _job({
  JobStatus status = JobStatus.processing,
  JobStage stage = JobStage.claims,
  JobError? error,
}) => Job(
  id: 'j1',
  status: status,
  createdAt: _start,
  stage: stage,
  stageDetail: status == JobStatus.processing ? 'Found 4 claims' : null,
  title: 'Morning routine',
  error: error,
);

/// The view with a job that tests can swap, as Firestore updates would.
class _Host extends StatefulWidget {
  const _Host({required this.initial, super.key});

  final Job initial;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late Job job = widget.initial;

  void update(Job next) => setState(() => job = next);

  @override
  Widget build(BuildContext context) => ProcessingView(job: job);
}

final _host = GlobalKey<_HostState>();

Future<void> _pump(
  WidgetTester tester,
  Job job, {
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: Scaffold(
          body: _Host(key: _host, initial: job),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

LensOrbitPainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((p) => p.painter)
    .whereType<LensOrbitPainter>()
    .single;

void main() {
  testWidgets('running: stage, detail and progress are announced', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _job());

    expect(find.text('Finding claims'), findsOneWidget);
    expect(find.text('Found 4 claims'), findsOneWidget);
    expect(find.text('Step 2 of 5'), findsOneWidget);
    // The bar eases with real time inside the stage, so only its range is
    // fixed: stage 2 of 5 starts at 20%.
    final progress = tester.getSemantics(
      find.bySemanticsLabel('Check progress'),
    );
    expect(
      int.parse(progress.value.replaceAll('%', '')),
      inInclusiveRange(20, 39),
    );
    expect(find.bySemanticsLabel(RegExp(r'^Elapsed \d+ seconds$')), findsOne);
    expect(_painter(tester).phase, OrbitPhase.running);
    expect(_painter(tester).lap.status, AnimationStatus.forward);
    semantics.dispose();
  });

  testWidgets('a new stage swaps the title and the step', (tester) async {
    await _pump(tester, _job());
    _host.currentState!.update(_job(stage: JobStage.checking));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Checking claims'), findsOneWidget);
    expect(find.text('Step 3 of 5'), findsOneWidget);
  });

  testWidgets('done: the lens parks, the ring closes, progress is full', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _job(stage: JobStage.report));
    _host.currentState!.update(
      _job(status: JobStatus.done, stage: JobStage.report),
    );
    // The close starts on the frame that sees the update.
    await tester.pump();
    await tester.pump(LensOrbit.close + const Duration(milliseconds: 100));

    final painter = _painter(tester);
    expect(painter.phase, OrbitPhase.done);
    expect(painter.lap.isAnimating, isFalse);
    expect(painter.close.value, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Check progress')),
      matchesSemantics(label: 'Check progress', value: '100%'),
    );
    semantics.dispose();
  });

  testWidgets('failed: the orbit stops and the error offers a retry', (
    tester,
  ) async {
    await _pump(tester, _job(stage: JobStage.evidence));
    _host.currentState!.update(
      _job(
        status: JobStatus.failed,
        stage: JobStage.evidence,
        error: const JobError(
          code: 'pipeline',
          message: "We couldn't finish this check.",
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(_painter(tester).phase, OrbitPhase.failed);
    expect(_painter(tester).lap.isAnimating, isFalse);
    expect(find.text('Check failed'), findsOneWidget);
    expect(find.text("We couldn't finish this check."), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('Usually 1 to 3 minutes'), findsNothing);
    final elapsed = find.byWidgetPredicate(
      (w) => w is Text && (w.semanticsLabel ?? '').startsWith('Elapsed'),
    );
    final clock = tester.widget<Text>(elapsed).semanticsLabel;
    // The clock reads the wall clock, so let real time pass.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1500)),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widget<Text>(elapsed).semanticsLabel,
      clock,
      reason: 'the clock stops when the check fails',
    );
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.color, AppTheme.light.colorScheme.error);
  });

  testWidgets('system reduced motion: the lens breathes in place', (
    tester,
  ) async {
    await _pump(tester, _job(), reduceMotion: true);
    final painter = _painter(tester);
    expect(painter.reduced, isTrue);
    // Breathing goes forward and back instead of lapping.
    expect(painter.lap.isAnimating, isTrue);
    await tester.pump(LensOrbit.lap * 2 + const Duration(milliseconds: 50));
    expect(painter.lap.status, AnimationStatus.reverse);
  });

  testWidgets('system reduced motion: done closes the ring at once', (
    tester,
  ) async {
    await _pump(tester, _job(stage: JobStage.report), reduceMotion: true);
    _host.currentState!.update(
      _job(status: JobStatus.done, stage: JobStage.report),
    );
    await tester.pump();
    expect(_painter(tester).close.value, 1);
    expect(_painter(tester).parkFrom, 0);
  });
}
