import 'dart:async';

import 'package:contextlens/features/drafts/draft.dart';
import 'package:contextlens/features/drafts/draft_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The creator's drafts, newest first, at most [limit].
class DraftsController extends AsyncNotifier<List<Draft>> {
  static const limit = 2;

  DraftRepository get _repository => ref.read(draftRepositoryProvider);

  @override
  Future<List<Draft>> build() => ref.watch(draftRepositoryProvider).list();

  /// The draft that saving [draft] would push out: the oldest one, when
  /// [draft] is new and the limit is reached. Null otherwise.
  Draft? evictionFor(Draft draft) {
    final drafts = state.value ?? const <Draft>[];
    if (drafts.any((d) => d.id == draft.id)) return null;
    if (drafts.length < limit) return null;
    return drafts.reduce((a, b) => a.updatedAt.isBefore(b.updatedAt) ? a : b);
  }

  /// Saves [draft], deleting the oldest first when the limit needs it.
  Future<void> save(Draft draft) async {
    final evict = evictionFor(draft);
    if (evict != null) await _repository.delete(evict.id);
    await _repository.save(draft);
    state = AsyncData(await _repository.list());
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    state = AsyncData(await _repository.list());
  }

  Future<void> deleteAll() async {
    await _repository.deleteAll();
    state = const AsyncData([]);
  }

  Draft? byId(String id) {
    for (final draft in state.value ?? const <Draft>[]) {
      if (draft.id == id) return draft;
    }
    return null;
  }
}

final draftsControllerProvider =
    AsyncNotifierProvider<DraftsController, List<Draft>>(DraftsController.new);
