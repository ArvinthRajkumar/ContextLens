import 'dart:async';

import 'package:contextlens/core/config.dart';
import 'package:contextlens/features/compose/declaration.dart';
import 'package:contextlens/features/compose/video_inspector.dart';
import 'package:contextlens/features/report/mock_backend.dart';
import 'package:contextlens/features/upload/fake_upload_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

sealed class UploadFailure {
  const UploadFailure();

  /// Worth retrying automatically with backoff.
  bool get isTransient;
}

/// A dropped connection, timeout, 5xx, 408 or 429.
final class UploadNetworkError extends UploadFailure {
  const UploadNetworkError();

  @override
  bool get isTransient => true;
}

/// The signed upload link or session expired; a new one is needed.
final class UploadExpired extends UploadFailure {
  const UploadExpired();

  @override
  bool get isTransient => false;
}

/// A non-retryable server response (4xx other than 408 and 429).
final class UploadRejected extends UploadFailure {
  const UploadRejected(this.code);

  final String code;

  @override
  bool get isTransient => false;
}

class UploadException implements Exception {
  const UploadException(this.failure);

  final UploadFailure failure;
}

/// Stops an in-flight transfer. The committed offset is kept, so a later
/// upload resumes from it.
class UploadCancelToken {
  final _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;

  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}

@immutable
class UploadSession {
  const UploadSession({required this.jobId, required this.totalBytes});

  final String jobId;
  final int totalBytes;
}

/// The upload protocol (spec section 5): open a resumable session, send
/// the file in chunks from the committed offset, then submit the job.
abstract interface class UploadRepository {
  Future<UploadSession> createSession(PickedVideo video);

  /// Bytes the server has committed, to resume from.
  Future<int> committedBytes(UploadSession session);

  /// Sends from [fromByte] to the end, emitting the bytes sent so far.
  /// Completes early, without error, when [cancel] fires. Throws
  /// [UploadException] on failure.
  Stream<int> upload(
    UploadSession session, {
    required int fromByte,
    required UploadCancelToken cancel,
  });

  /// Starts the check. Returns the job id to watch.
  Future<String> submit(
    UploadSession session, {
    required PickedVideo video,
    required DeclarationDraft declaration,
    String? parentJobId,
  });

  /// Discards the session and anything uploaded.
  Future<void> discard(UploadSession session);
}

/// Debug: makes the next mock upload fail once part way (MOCK_FAIL=1 or the
/// debug menu).
class MockFailNextUpload extends Notifier<bool> {
  @override
  bool build() => AppConfig.mockFail;

  void set({required bool fail}) => state = fail;

  /// Returns whether to fail, and clears the flag.
  bool consume() {
    final fail = state;
    state = false;
    return fail;
  }
}

final mockFailNextUploadProvider = NotifierProvider<MockFailNextUpload, bool>(
  MockFailNextUpload.new,
);

final uploadRepositoryProvider = Provider<UploadRepository>((ref) {
  return switch (AppConfig.backend) {
    BackendMode.mock => FakeUploadRepository(
      backend: ref.watch(mockBackendProvider),
      bytesPerSecond: AppConfig.mockUploadBytesPerSecond,
      shouldFail: ref.read(mockFailNextUploadProvider.notifier).consume,
    ),
    // Phase 6: dio against a GCS resumable session.
    BackendMode.real => throw UnimplementedError('Real backend not wired yet'),
  };
});
