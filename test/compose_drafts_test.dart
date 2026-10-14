import 'package:contextlens/core/theme/app_theme.dart';
import 'package:contextlens/features/compose/compose_page.dart';
import 'package:contextlens/features/compose/declaration.dart';
import 'package:contextlens/features/drafts/draft.dart';
import 'package:contextlens/features/drafts/draft_repository.dart';
import 'package:contextlens/features/drafts/drafts_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Draft _draft(String id, int minutesAgo, String caption) => Draft(
  id: id,
  updatedAt: DateTime.now().subtract(Duration(minutes: minutesAgo)),
  declaration: DeclarationDraft(caption: caption),
);

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester,
    List<Draft> drafts,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        draftRepositoryProvider.overrideWithValue(
          MemoryDraftRepository(drafts),
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/new'),
              child: const Text('open'),
            ),
          ),
          routes: [
            GoRoute(path: 'new', builder: (_, _) => const ComposePage()),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Caption'),
      'My new reel',
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> leave(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
  }

  List<String> titles(ProviderContainer c) =>
      c.read(draftsControllerProvider).value!.map((d) => d.title).toList();

  testWidgets('leaving saves a draft', (tester) async {
    final container = await pump(tester, const []);
    await leave(tester);
    expect(titles(container), ['My new reel']);
  });

  testWidgets('at the limit, Save replaces the oldest draft', (tester) async {
    final container = await pump(tester, [
      _draft('a', 60, 'Oldest reel'),
      _draft('b', 5, 'Newer reel'),
    ]);
    await leave(tester);
    expect(
      find.text(
        'You can keep 2 drafts. Saving this will delete your oldest draft, '
        "'Oldest reel'.",
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(titles(container), ['My new reel', 'Newer reel']);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('at the limit, Discard keeps both drafts', (tester) async {
    final container = await pump(tester, [
      _draft('a', 60, 'Oldest reel'),
      _draft('b', 5, 'Newer reel'),
    ]);
    await leave(tester);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(titles(container), ['Newer reel', 'Oldest reel']);
    expect(find.text('open'), findsOneWidget);
  });
}
