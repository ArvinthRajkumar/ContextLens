import 'package:contextlens/core/utils/formatters.dart';
import 'package:contextlens/core/utils/validators.dart';
import 'package:contextlens/features/compose/declaration.dart';
import 'package:contextlens/features/compose/video_inspector.dart';
import 'package:contextlens/features/compose/video_source.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

sealed class VideoSlot {
  const VideoSlot();
}

final class VideoEmpty extends VideoSlot {
  const VideoEmpty();
}

// Each slot carries the name shown to the user, which can differ from the
// file name (see [ComposeController.displayNameFor]).

final class VideoInspecting extends VideoSlot {
  const VideoInspecting(this.name);

  final String name;
}

final class VideoReady extends VideoSlot {
  const VideoReady(this.video, this.name);

  final PickedVideo video;
  final String name;
}

final class VideoRejected extends VideoSlot {
  const VideoRejected(this.name, this.problem);

  final String name;
  final VideoProblem problem;

  /// A timeout can succeed on a second try; other problems can't.
  bool get canRetry => problem is VideoDecodeTimeout;
}

@immutable
class ComposeState {
  const ComposeState({
    this.video = const VideoEmpty(),
    this.declaration = const DeclarationDraft(),
  });

  final VideoSlot video;
  final DeclarationDraft declaration;

  /// What still blocks "Run check", or null when it can run.
  String? get blocker => switch (video) {
    VideoEmpty() || VideoRejected() => 'Pick a video to continue',
    VideoInspecting() => 'Checking your video',
    VideoReady() => declaration.firstProblem,
  };

  bool get canSubmit => blocker == null;

  ComposeState copyWith({VideoSlot? video, DeclarationDraft? declaration}) {
    return ComposeState(
      video: video ?? this.video,
      declaration: declaration ?? this.declaration,
    );
  }
}

@immutable
class ComposeSubmission {
  const ComposeSubmission({
    required this.video,
    required this.declaration,
    this.parentJobId,
  });

  final PickedVideo video;
  final DeclarationDraft declaration;
  final String? parentJobId;
}

class ComposeController extends Notifier<ComposeState> {
  int _nextClipId = 0;

  // Bumped per pick so a slow inspection can't overwrite a newer pick.
  int _pickToken = 0;

  // Kept so a timed-out inspection can be retried.
  ({PickedFile file, String name})? _lastPick;

  // The photo picker hands back media IDs such as "36.mp4".
  static final _numericName = RegExp(r'^\d+(\.\w+)?$');

  /// Gallery picks with a meaningless numeric name get a readable label.
  /// Shared files and file picks keep their real name.
  static String displayNameFor(
    PickedFile file, {
    required bool fromGallery,
    DateTime? now,
  }) {
    if (!fromGallery || !_numericName.hasMatch(file.name)) return file.name;
    return 'Video from gallery, ${formatShortDate(now ?? DateTime.now())}';
  }

  @override
  ComposeState build() => const ComposeState();

  /// Starts a fresh check.
  void reset() {
    _pickToken++;
    state = const ComposeState();
  }

  /// Starts a fix of an earlier run: keeps its declaration, asks for the
  /// edited video.
  void startFix(DeclarationDraft? declaration) {
    _pickToken++;
    final draft = declaration ?? const DeclarationDraft();
    for (final clip in draft.clips) {
      if (clip.id >= _nextClipId) _nextClipId = clip.id + 1;
    }
    state = ComposeState(declaration: draft);
  }

  Future<void> pickFromGallery() =>
      _pick(ref.read(videoSourceProvider).pickFromGallery, fromGallery: true);

  Future<void> pickFromFiles() =>
      _pick(ref.read(videoSourceProvider).pickFromFiles, fromGallery: false);

  /// A file shared into the app from another app. Keeps the declaration.
  Future<void> useSharedFile(String path) {
    final name = path.split(RegExp(r'[\\/]')).last;
    return _inspect(PickedFile(path: path, name: name), name);
  }

  /// Inspects the last picked file again, after a timeout.
  Future<void> retryInspection() async {
    final last = _lastPick;
    if (last != null) await _inspect(last.file, last.name);
  }

  void removeVideo() {
    _pickToken++;
    state = state.copyWith(video: const VideoEmpty());
  }

  Future<void> _pick(
    Future<PickedFile?> Function() pick, {
    required bool fromGallery,
  }) async {
    final file = await pick();
    // Cancelling the picker leaves the current video in place.
    if (file == null) return;
    await _inspect(file, displayNameFor(file, fromGallery: fromGallery));
  }

  Future<void> _inspect(PickedFile file, String name) async {
    final token = ++_pickToken;
    _lastPick = (file: file, name: name);
    state = state.copyWith(video: VideoInspecting(name));
    final result = await ref
        .read(videoInspectorProvider)
        .inspect(file.path, name: file.name, mimeType: file.mimeType);
    if (token != _pickToken) return;
    state = state.copyWith(
      video: switch (result) {
        InspectionPassed(:final video) => VideoReady(video, name),
        InspectionFailed(:final problem) => VideoRejected(name, problem),
      },
    );
  }

  void updateDeclaration(DeclarationDraft Function(DeclarationDraft) update) {
    state = state.copyWith(declaration: update(state.declaration));
  }

  void addClip() => updateDeclaration(
    (d) => d.copyWith(
      clips: [
        ...d.clips,
        ClipDraft(id: _nextClipId++),
      ],
    ),
  );

  void updateClip(int id, ClipDraft Function(ClipDraft) update) =>
      updateDeclaration(
        (d) => d.copyWith(
          clips: [
            for (final clip in d.clips) clip.id == id ? update(clip) : clip,
          ],
        ),
      );

  void removeClip(int id) => updateDeclaration(
    (d) => d.copyWith(
      clips: [
        for (final c in d.clips)
          if (c.id != id) c,
      ],
    ),
  );

  Future<void> attachClipFile(int id) async {
    final file = await ref.read(videoSourceProvider).pickFromFiles();
    if (file == null) return;
    updateClip(id, (c) => c.copyWith(filePath: file.path, fileName: file.name));
  }

  ComposeSubmission? buildSubmission({String? parentJobId}) {
    final video = state.video;
    if (!state.canSubmit || video is! VideoReady) return null;
    return ComposeSubmission(
      video: video.video,
      declaration: state.declaration,
      parentJobId: parentJobId,
    );
  }
}

final composeControllerProvider =
    NotifierProvider<ComposeController, ComposeState>(ComposeController.new);

/// Handed from Compose to Run until the upload pipeline (Phase 4) takes it.
class PendingSubmission extends Notifier<ComposeSubmission?> {
  @override
  ComposeSubmission? build() => null;

  void set(ComposeSubmission submission) => state = submission;
}

final pendingSubmissionProvider =
    NotifierProvider<PendingSubmission, ComposeSubmission?>(
      PendingSubmission.new,
    );
