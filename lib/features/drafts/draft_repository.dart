import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:contextlens/core/log.dart';
import 'package:contextlens/features/compose/declaration.dart';
import 'package:contextlens/features/drafts/draft.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Where drafts live. The device keeps them in app-private storage; tests
/// and the web keep them in memory.
abstract interface class DraftRepository {
  /// Newest first.
  Future<List<Draft>> list();

  /// Saves (or replaces) [draft], copying its video and clip files into
  /// private storage so they outlive the picker's cache. Returns the draft
  /// as stored, with paths pointing at the copies.
  Future<Draft> save(Draft draft);

  Future<void> delete(String id);

  Future<void> deleteAll();
}

class FileDraftRepository implements DraftRepository {
  FileDraftRepository({Future<Directory> Function()? root})
    : _root = root ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _root;

  static const _json = 'draft.json';
  static const _thumb = 'thumb.jpg';

  Future<Directory> _dir([String? id]) async {
    final base = Directory('${(await _root()).path}/drafts');
    return id == null ? base : Directory('${base.path}/$id');
  }

  @override
  Future<List<Draft>> list() async {
    final base = await _dir();
    if (!base.existsSync()) return [];
    final drafts = <Draft>[];
    for (final entry in base.listSync().whereType<Directory>()) {
      final file = File('${entry.path}/$_json');
      if (!file.existsSync()) continue;
      try {
        final thumb = File('${entry.path}/$_thumb');
        drafts.add(
          Draft.fromJson(
            jsonDecode(await file.readAsString()) as Map<String, Object?>,
            thumbnail: thumb.existsSync() ? await thumb.readAsBytes() : null,
          ),
        );
      } on Object catch (error) {
        log('Unreadable draft skipped: ${error.runtimeType}');
      }
    }
    return drafts..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// Copies [path] into [dir] unless it is already there.
  Future<String> _keep(String path, Directory dir, String name) async {
    if (path.startsWith(dir.path)) return path;
    final ext = path.contains('.') ? path.split('.').last : 'bin';
    final target = '${dir.path}/$name.$ext';
    await File(path).copy(target);
    return target;
  }

  @override
  Future<Draft> save(Draft draft) async {
    final dir = await _dir(draft.id);
    await dir.create(recursive: true);
    var stored = draft;
    final video = draft.video;
    if (video != null) {
      final path = await _keep(video.path, dir, 'video');
      stored = stored.copyWith(video: video.atPath(path));
      final thumb = video.thumbnail;
      if (thumb != null) await File('${dir.path}/$_thumb').writeAsBytes(thumb);
    }
    final clips = <ClipDraft>[];
    for (final clip in draft.declaration.clips) {
      final path = clip.filePath;
      clips.add(
        path == null || !File(path).existsSync()
            ? clip
            : clip.copyWith(
                filePath: await _keep(path, dir, 'clip-${clip.id}'),
              ),
      );
    }
    stored = stored.copyWith(
      declaration: stored.declaration.copyWith(clips: clips),
    );
    await File('${dir.path}/$_json').writeAsString(stored.encode());
    return stored;
  }

  @override
  Future<void> delete(String id) async {
    final dir = await _dir(id);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  @override
  Future<void> deleteAll() async {
    final base = await _dir();
    if (base.existsSync()) await base.delete(recursive: true);
  }
}

class MemoryDraftRepository implements DraftRepository {
  MemoryDraftRepository([List<Draft> drafts = const []])
    : _drafts = {for (final d in drafts) d.id: d};

  final Map<String, Draft> _drafts;

  @override
  Future<List<Draft>> list() async =>
      _drafts.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Future<Draft> save(Draft draft) async => _drafts[draft.id] = draft;

  @override
  Future<void> delete(String id) async => _drafts.remove(id);

  @override
  Future<void> deleteAll() async => _drafts.clear();
}

final draftRepositoryProvider = Provider<DraftRepository>(
  (ref) => kIsWeb ? MemoryDraftRepository() : FileDraftRepository(),
);
