import 'package:contextlens/core/theme/app_theme.dart';
import 'package:contextlens/features/run/success_burst.dart';
import 'package:contextlens/features/run/upload_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Frame timings for the upload success animation. Run in profile mode:
// flutter drive --profile --driver=test_driver/perf_driver.dart
//   --target=integration_test/success_burst_perf_test.dart
// The summary is written to build/success_burst_perf.json.

const _plays = 5;
const _budgetMs = 1000 / 60;

class _Harness extends StatefulWidget {
  const _Harness({required this.onReady});

  final ValueChanged<AnimationController> onReady;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SuccessBurst.total,
  );

  @override
  void initState() {
    super.initState();
    widget.onReady(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox.square(
          dimension: UploadRing.size,
          child: SuccessBurst(animation: _controller),
        ),
      ),
    );
  }
}

double _ms(Duration d) => d.inMicroseconds / 1000;

Map<String, num> _stats(List<double> values) {
  final sorted = [...values]..sort();
  double pct(double p) => sorted[((sorted.length - 1) * p).round()];
  return {
    'average': values.reduce((a, b) => a + b) / values.length,
    'p50': pct(0.5),
    'p90': pct(0.9),
    'p99': pct(0.99),
    'worst': sorted.last,
  };
}

Future<Map<String, Object>> _measure(
  WidgetTester tester,
  Future<void> Function() play,
) async {
  final timings = <FrameTiming>[];
  void collect(List<FrameTiming> batch) => timings.addAll(batch);
  SchedulerBinding.instance.addTimingsCallback(collect);
  await play();
  // Timings arrive in batches; give the last one time to land.
  await tester.pump(const Duration(seconds: 1));
  SchedulerBinding.instance.removeTimingsCallback(collect);

  final build = [for (final t in timings) _ms(t.buildDuration)];
  final raster = [for (final t in timings) _ms(t.rasterDuration)];
  final total = [for (final t in timings) _ms(t.totalSpan)];
  return {
    'frames': timings.length,
    'budget_ms': _budgetMs,
    'build_ms': _stats(build),
    'raster_ms': _stats(raster),
    'total_span_ms': _stats(total),
    'frames_over_budget_build': build.where((v) => v > _budgetMs).length,
    'frames_over_budget_raster': raster.where((v) => v > _budgetMs).length,
  };
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    // Real frames, so the engine reports real build and raster timings.
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  final report = <String, Object>{};

  tearDownAll(() => binding.reportData = {'success_burst': report});

  testWidgets('success burst frame timings', (tester) async {
    late AnimationController controller;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: _Harness(onReady: (c) => controller = c),
      ),
    );
    await tester.pumpAndSettle();

    report['burst'] = await _measure(tester, () async {
      for (var i = 0; i < _plays; i++) {
        await controller.forward(from: 0);
        await tester.pump(const Duration(milliseconds: 200));
      }
    });
  });

  // The same window with only a stock spinner animating, to separate the
  // device's per-frame floor from the painter's own cost.
  testWidgets('baseline frame timings', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    report['baseline_spinner'] = await _measure(
      tester,
      () => tester.pump(const Duration(milliseconds: 7000)),
    );
  });
}
