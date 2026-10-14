import 'dart:io';

import 'package:contextlens/core/utils/validators.dart';
import 'package:contextlens/features/compose/declaration.dart';
import 'package:contextlens/features/compose/video_inspector.dart';
import 'package:contextlens/features/drafts/draft.dart';
import 'package:contextlens/features/drafts/draft_repository.dart';
import 'package:contextlens/features/drafts/drafts_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Draft _draft(String id, int minutesAgo, {String caption = 'A caption'}) =>
    Draft(
      id: id,
      updatedAt: DateTime(
        2026,
        10,
        14,
        12,
      ).subtract(Duration(minutes: minutesAgo)),
      declaration: DeclarationDraft(caption: caption),
    );

void main() {
  group('two-draft limit', () {
    late ProviderContainer container;
    late DraftsController drafts;

    Future<void> start(List<Draft> existing) async {
      container = ProviderContainer(
        overrides: [
          draftRepositoryProvider.overrideWithValue(
            MemoryDraftRepository(existing),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(draftsControllerProvider.future);
      drafts = container.read(draftsControllerProvider.notifier);
    }

    test('saves freely below the limit', () async {
      await start([_draft('a', 10)]);
      final next = _draft('b', 0);
      expect(drafts.evictionFor(next), isNull);
      await drafts.save(next);
      expect(container.read(draftsControllerProvider).value, hasLength(2));
    });

    test('a third draft would replace the oldest', () async {
      await start([_draft('old', 30, caption: 'Oldest one'), _draft('new', 5)]);
      final third = _draft('third', 0);
      expect(drafts.evictionFor(third)?.title, 'Oldest one');

      await drafts.save(third);
      final ids = container
          .read(draftsControllerProvider)
          .value!
          .map((d) => d.id)
          .toList();
      expect(ids, ['third', 'new']);
    });

    test('updating an existing draft never evicts', () async {
      await start([_draft('a', 30), _draft('b', 5)]);
      final edited = _draft('a', 0, caption: 'Edited');
      expect(drafts.evictionFor(edited), isNull);
      await drafts.save(edited);
      expect(container.read(draftsControllerProvider).value, hasLength(2));
      expect(
        container.read(draftsControllerProvider).value!.first.title,
        'Edited',
      );
    });

    test('delete and delete all', () async {
      await start([_draft('a', 30), _draft('b', 5)]);
      await drafts.delete('a');
      expect(container.read(draftsControllerProvider).value, hasLength(1));
      await drafts.deleteAll();
      expect(container.read(draftsControllerProvider).value, isEmpty);
    });
  });

  test('files are copied into private storage and restored', () async {
    final root = await Directory.systemTemp.createTemp('drafts');
    addTearDown(() => root.delete(recursive: true));
    final picked = File('${root.path}/picked.mp4')..writeAsBytesSync([1, 2, 3]);
    final repository = FileDraftRepository(root: () async => root);
    final draft = Draft(
      id: 'd1',
      updatedAt: DateTime.utc(2026, 10, 14, 9),
      videoName: 'Video from gallery, 14 Oct',
      video: PickedVideo(
        path: picked.path,
        name: 'picked.mp4',
        sizeBytes: 3,
        container: VideoContainer.mp4,
        duration: const Duration(seconds: 12),
        width: 720,
        height: 1280,
      ),
      declaration: const DeclarationDraft(
        caption: 'Morning routine',
        isPaid: true,
        brand: 'VitaBoost',
        category: ContentCategory.health,
      ),
    );

    final stored = await repository.save(draft);
    expect(stored.video!.path, isNot(picked.path));
    picked.deleteSync();
    expect(File(stored.video!.path).readAsBytesSync(), [1, 2, 3]);

    final [restored] = await repository.list();
    expect(restored.title, 'Morning routine');
    expect(restored.declaration.brand, 'VitaBoost');
    expect(restored.video!.duration, const Duration(seconds: 12));
  });

  test('edited time reads naturally', () {
    final now = DateTime(2026, 10, 14, 12);
    expect(editedAgo(now, now: now), 'Edited just now');
    expect(
      editedAgo(now.subtract(const Duration(minutes: 5)), now: now),
      'Edited 5 min ago',
    );
    expect(
      editedAgo(now.subtract(const Duration(hours: 3)), now: now),
      'Edited 3 h ago',
    );
  });
}
