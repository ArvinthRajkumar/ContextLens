import 'package:contextlens/core/theme/app_theme.dart';
import 'package:contextlens/features/report/job_repository.dart';
import 'package:contextlens/features/settings/delete_data_tile.dart';
import 'package:contextlens/features/settings/mock_data_controller.dart';
import 'package:contextlens/features/settings/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'debug.seedMockData': true});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: DeleteDataTile()),
        ),
      ),
    );
  }

  testWidgets('cancel keeps everything', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Delete my data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(container.read(mockDataControllerProvider), isTrue);
    expect(find.text('Your data is deleted.'), findsNothing);
  });

  testWidgets('confirming deletes every check and says so', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Delete my data'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your data?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Your data is deleted.'), findsOneWidget);
    expect(container.read(mockDataControllerProvider), isFalse);
    final jobs = await container
        .read(jobRepositoryProvider)
        .watchRecentJobs()
        .first;
    expect(jobs, isEmpty);
  });
}
