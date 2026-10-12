import 'dart:async';
import 'dart:math';

import 'package:contextlens/core/utils/formatters.dart';
import 'package:contextlens/features/compose/declaration.dart';
import 'package:contextlens/features/compose/video_inspector.dart';
import 'package:contextlens/features/report/mock_backend.dart';
import 'package:contextlens/features/report/models.dart';
import 'package:contextlens/features/upload/upload_repository.dart';

/// Simulates a resumable upload at about [bytesPerSecond] with jitter.
/// Supports pause (cancel and resume from the committed offset), discard,
/// and one injected transient failure when [shouldFail] says so.
class FakeUploadRepository implements UploadRepository {
  FakeUploadRepository({
    required this.backend,
    required this.bytesPerSecond,
    required this.shouldFail,
    this.tick = const Duration(milliseconds: 100),
    Random? random,
  }) : _random = random ?? Random();

  final MockBackend backend;
  final int bytesPerSecond;
  final bool Function() shouldFail;
  final Duration tick;
  final Random _random;

  // Where the injected failure strikes, as a share of the file.
  static const _failAt = 0.4;
  static const _jitter = 0.3;

  final _committed = <String, int>{};
  final _failPending = <String>{};

  @override
  Future<UploadSession> createSession(PickedVideo video) async {
    final id = 'job_${DateTime.now().millisecondsSinceEpoch}';
    _committed[id] = 0;
    if (shouldFail()) _failPending.add(id);
    return UploadSession(jobId: id, totalBytes: video.sizeBytes);
  }

  @override
  Future<int> committedBytes(UploadSession session) async =>
      _committed[session.jobId] ?? 0;

  @override
  Stream<int> upload(
    UploadSession session, {
    required int fromByte,
    required UploadCancelToken cancel,
  }) async* {
    final total = session.totalBytes;
    var sent = fromByte;
    final perTick = bytesPerSecond * tick.inMilliseconds / 1000;
    while (sent < total) {
      await Future.any([Future<void>.delayed(tick), cancel.whenCancelled]);
      if (cancel.isCancelled) return;
      final jitter = 1 + (_random.nextDouble() * 2 - 1) * _jitter;
      sent = min(total, sent + (perTick * jitter).round());
      if (_failPending.contains(session.jobId) && sent >= total * _failAt) {
        _failPending.remove(session.jobId);
        throw const UploadException(UploadNetworkError());
      }
      _committed[session.jobId] = sent;
      yield sent;
    }
  }

  @override
  Future<String> submit(
    UploadSession session, {
    required PickedVideo video,
    required DeclarationDraft declaration,
    String? parentJobId,
  }) async {
    await backend.submit(
      jobId: session.jobId,
      title: titleFromCaption(declaration.caption),
      parentJobId: parentJobId,
      video: VideoMeta(
        durationMs: video.duration.inMilliseconds,
        width: video.width,
        height: video.height,
      ),
    );
    return session.jobId;
  }

  @override
  Future<void> discard(UploadSession session) async {
    _committed.remove(session.jobId);
    _failPending.remove(session.jobId);
  }
}
