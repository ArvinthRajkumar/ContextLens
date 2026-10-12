import 'package:contextlens/app.dart';
import 'package:contextlens/features/settings/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _app([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final instance = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(instance)],
    child: const ContextLensApp(),
  );
}

ThemeMode _themeMode(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

void main() {
  testWidgets('boots into Home in dark mode by default', (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();
    expect(find.text('ContextLens'), findsOneWidget);
    expect(_themeMode(tester), ThemeMode.dark);
  });

  testWidgets('theme choice persists', (tester) async {
    await tester.pumpWidget(await _app());
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
    await tester.pumpWidget(await _app({'appearance.themeMode': 'system'}));
    await tester.pumpAndSettle();
    expect(_themeMode(tester), ThemeMode.system);
  });
}
