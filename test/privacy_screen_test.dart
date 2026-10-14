import 'package:contextlens/core/theme/app_theme.dart';
import 'package:contextlens/core/widgets/lens_mark.dart';
import 'package:contextlens/core/widgets/privacy_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const channel = MethodChannel('contextlens/privacy');
  final calls = <Object?>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.arguments);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Widget app(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

  testWidgets('covers the report when the app leaves the foreground', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(const PrivacyScreen(child: Text('Brand deal without an Ad label'))),
    );
    expect(find.byType(LensMark), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byType(LensMark), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byType(LensMark), findsNothing);
  });

  testWidgets('the recents flag stays on until the last private screen goes', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const PrivacyScreen(child: PrivacyScreen(child: Text('flag detail'))),
      ),
    );
    expect(calls, [true]);

    await tester.pumpWidget(app(const PrivacyScreen(child: Text('report'))));
    expect(calls, [true], reason: 'one private screen is still open');

    await tester.pumpWidget(app(const Text('home')));
    expect(calls, [true, false]);
  });
}
