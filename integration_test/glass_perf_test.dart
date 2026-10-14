import 'package:contextlens/app.dart';
import 'package:contextlens/core/prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Frame timings for the glass redesign: scrolling Home over the sky
// gradient, and Settings with the blurred fire card on screen. Run in
// profile mode:
// flutter drive --profile --driver=test_driver/perf_driver.dart
//   --target=integration_test/glass_perf_test.dart
// The summary is written to build/glass_perf.json.

const _budgetMs = 1000 / 60;

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
  await tester.pump(const Duration(seconds: 1));
  SchedulerBinding.instance.removeTimingsCallback(collect);

  final build = [for (final t in timings) _ms(t.buildDuration)];
  final raster = [for (final t in timings) _ms(t.rasterDuration)];
  return {
    'frames': timings.length,
    'budget_ms': _budgetMs,
    'build_ms': _stats(build),
    'raster_ms': _stats(raster),
    'frames_over_budget_build': build.where((v) => v > _budgetMs).length,
    'frames_over_budget_raster': raster.where((v) => v > _budgetMs).length,
  };
}

Future<void> _scroll(WidgetTester tester, Finder list) async {
  for (var i = 0; i < 3; i++) {
    await tester.fling(list, const Offset(0, -600), 1500);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.fling(list, const Offset(0, 600), 1500);
    await tester.pump(const Duration(milliseconds: 900));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  final report = <String, Object>{};

  tearDownAll(() => binding.reportData = {'glass': report});

  testWidgets('glass screens frame timings', (tester) async {
    SharedPreferences.setMockInitialValues({'debug.seedMockData': true});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const ContextLensApp(),
      ),
    );
    // Past the intro.
    await tester.pump(const Duration(seconds: 4));

    report['home_scroll'] = await _measure(
      tester,
      () => _scroll(tester, find.byType(Scrollable).first),
    );

    await tester.tap(find.byTooltip('Settings'));
    await tester.pump(const Duration(seconds: 1));
    report['settings_fire_idle'] = await _measure(
      tester,
      () => tester.pump(const Duration(seconds: 4)),
    );
    report['settings_scroll'] = await _measure(
      tester,
      () => _scroll(tester, find.byType(Scrollable).first),
    );
  });
}
