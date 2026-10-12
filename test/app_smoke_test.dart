import 'package:contextlens/app.dart';
import 'package:contextlens/features/home/run_card.dart';
import 'package:contextlens/features/report/mock_backend.dart';
import 'package:contextlens/features/settings/theme_controller.dart';
import 'package:contextlens/features/splash/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _app(
  WidgetTester tester, {
  bool seeded = false,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    ...prefs,
    if (seeded) 'debug.seedMockData': true,
  });
  final instance = await SharedPreferences.getInstance();
  // Fixture loading is real I/O, so warm the cache outside fake time.
  final backend = MockBackend();
  await tester.runAsync(backend.fixtures);
  addTearDown(backend.dispose);
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(instance),
      mockBackendProvider.overrideWithValue(backend),
    ],
    child: const ContextLensApp(),
  );
}

ThemeMode _themeMode(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

void main() {
  testWidgets('intro hands off to an empty Home in dark mode', (tester) async {
    await tester.pumpWidget(await _app(tester));
    await tester.pumpAndSettle();

    expect(find.text('Check a video before you post'), findsOneWidget);
    expect(find.text('No checks yet'), findsOneWidget);
    expect(_themeMode(tester), ThemeMode.dark);
  });

  testWidgets('intro covers the whole screen', (tester) async {
    await tester.pumpWidget(await _app(tester));
    await tester.pump(const Duration(milliseconds: 500));

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(tester.getSize(find.byType(SplashPage)), screen);
    await tester.pumpAndSettle();
    expect(find.byType(SplashPage), findsNothing);
  });

  testWidgets('seeded mock data shows run cards', (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(await _app(tester, seeded: true));
    await tester.pumpAndSettle();

    expect(find.byType(RunCard), findsNWidgets(3));
    expect(find.text('3 of 4 resolved'), findsOneWidget);
    expect(find.text('Check failed'), findsOneWidget);
  });

  testWidgets('theme choice persists', (tester) async {
    await tester.pumpWidget(await _app(tester));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    expect(_themeMode(tester), ThemeMode.light);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('appearance.themeMode'), 'light');
  });

  testWidgets('restores a stored theme', (tester) async {
    await tester.pumpWidget(
      await _app(tester, prefs: {'appearance.themeMode': 'system'}),
    );
    await tester.pumpAndSettle();
    expect(_themeMode(tester), ThemeMode.system);
  });

  testWidgets('Home survives 2x text scale without overflow', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(await _app(tester, seeded: true));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
