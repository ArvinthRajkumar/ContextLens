import 'package:contextlens/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots into Home', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ContextLensApp()));
    await tester.pumpAndSettle();
    expect(find.text('ContextLens'), findsOneWidget);
  });
}
