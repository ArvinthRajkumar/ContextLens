import 'dart:async';
import 'dart:io';

import 'package:contextlens/core/api_client.dart';
import 'package:contextlens/core/log.dart';
import 'package:contextlens/features/compose/declaration.dart';
import 'package:contextlens/features/compose/video_inspector.dart';
import 'package:contextlens/features/upload/resumable_protocol.dart';
import 'package:contextlens/features/upload/upload_repository.dart';
import 'package:contextlens/features/upload/upload_session_store.dart';
import 'package:dio/dio.dart';

/// The real upload: the API hands out a signed URL that opens a GCS
/// resumable session, then the file goes up in chunks straight to Cloud
/// Storage, resuming from whatever offset the server reports.
class HttpUploadRepository implements UploadRepository {
  HttpUploadRepository({required this._api, required this._store, Dio? storage})
    : // No auth interceptor: GCS authenticates the session URI itself.
      _gcs =
          storage ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(minutes: 2),
              receiveTimeout: const Duration(seconds: 30),
              // 308 is the protocol's "keep going", not an error.
              validateStatus: (status) =>
                  status != null &&
                  (status == 200 ||
                      status == 201 ||
                      status == kResumeIncomplete),
            ),
          );

  final ApiClient _api;
  final UploadSessionStore _store;
  final Dio _gcs;

  // Open sessions this process knows about, by job id.
  final _sessions = <String, StoredUpload>{};

  @override
  Future<UploadSession> createSession(PickedVideo video) async {
    final Map<String, dynamic> created;
    try {
      created = await _api.post('/v1/uploads', {
        'fileName': video.name,
        'contentType': _mimeFor(video),
        'sizeBytes': video.sizeBytes,
      });
    } on ApiException catch (e) {
      throw UploadException(_failureFor(e));
    }

    final jobId = created['jobId'] as String;
    final sessionUri = await _openSession(
      Uri.parse(created['uploadUrl'] as String),
      _mimeFor(video),
      video.sizeBytes,
    );
    final stored = StoredUpload(
      jobId: jobId,
      sessionUri: sessionUri,
      filePath: video.path,
      totalBytes: video.sizeBytes,
      chunkSize: validChunkSize(created['chunkSize'] as int? ?? 8 << 20),
      createdAt: DateTime.now(),
    );
    _sessions[jobId] = stored;
    await _store.save(stored);
    return UploadSession(jobId: jobId, totalBytes: video.sizeBytes);
  }

  Future<String> _openSession(Uri url, String contentType, int size) async {
    try {
      final response = await _gcs.postUri<void>(
        url,
        options: Options(
          headers: {
            'x-goog-resumable': 'start',
            'Content-Type': contentType,
            'X-Upload-Content-Length': '$size',
          },
        ),
      );
      final location = response.headers.value('location');
      if (location == null) {
        throw const UploadException(UploadRejected('no_session'));
      }
      return location;
    } on DioException catch (e) {
      throw UploadException(_gcsFailure(e));
    }
  }

  @override
  Future<int> committedBytes(UploadSession session) async {
    final stored = _require(session.jobId);
    try {
      final response = await _gcs.put<void>(
        stored.sessionUri,
        options: Options(
          headers: {
            'Content-Range': statusRange(stored.totalBytes),
            Headers.contentLengthHeader: 0,
          },
        ),
      );
      if (response.statusCode != kResumeIncomplete) return stored.totalBytes;
      return committedFromRange(response.headers.value('range'));
    } on DioException catch (e) {
      throw UploadException(_gcsFailure(e));
    }
  }

  @override
  Stream<int> upload(
    UploadSession session, {
    required int fromByte,
    required UploadCancelToken cancel,
  }) {
    final stored = _require(session.jobId);
    final controller = StreamController<int>();
    final dioCancel = CancelToken();
    unawaited(cancel.whenCancelled.then((_) => dioCancel.cancel()));

    Future<void> run() async {
      final file = File(stored.filePath);
      final total = stored.totalBytes;
      var offset = fromByte;
      try {
        while (offset < total && !cancel.isCancelled) {
          final end = chunkEnd(offset, stored.chunkSize, total);
          final start = offset;
          final response = await _gcs.put<void>(
            stored.sessionUri,
            data: file.openRead(start, end + 1),
            cancelToken: dioCancel,
            options: Options(
              headers: {
                'Content-Range': chunkRange(start, end, total),
                Headers.contentLengthHeader: end - start + 1,
              },
            ),
            onSendProgress: (sent, _) {
              if (!controller.isClosed) controller.add(start + sent);
            },
          );
          offset = response.statusCode == kResumeIncomplete
              ? committedFromRange(response.headers.value('range'))
              : total;
          if (!controller.isClosed) controller.add(offset);
        }
      } on DioException catch (e) {
        if (!CancelToken.isCancel(e) && !controller.isClosed) {
          controller.addError(UploadException(_gcsFailure(e)));
        }
      } on FileSystemException {
        if (!controller.isClosed) {
          controller.addError(
            const UploadException(UploadRejected('file_unreadable')),
          );
        }
      } finally {
        await controller.close();
      }
    }

    controller.onListen = () => unawaited(run());
    return controller.stream;
  }

  @override
  Future<String> submit(
    UploadSession session, {
    required PickedVideo video,
    required DeclarationDraft declaration,
    String? parentJobId,
  }) async {
    await _uploadClips(session.jobId, declaration);
    try {
      await _api.post('/v1/jobs/${session.jobId}/submit', {
        'declaration': declaration.toJson(),
        'parentJobId': ?parentJobId,
        'video': {
          'durationMs': video.duration.inMilliseconds,
          'width': video.width,
          'height': video.height,
        },
      });
    } on ApiException catch (e) {
      throw UploadException(_failureFor(e));
    }
    _sessions.remove(session.jobId);
    await _store.clear();
    return session.jobId;
  }

  static const _clipTypes = {
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'webm': 'video/webm',
    'mp3': 'audio/mpeg',
    'm4a': 'audio/mp4',
    'aac': 'audio/aac',
    'wav': 'audio/wav',
  };

  /// Sends each attached clip original to `clips/{index}` before submit, so
  /// the backend can compare the creator's cut with it. Clips are small,
  /// so each goes in one request.
  Future<void> _uploadClips(String jobId, DeclarationDraft declaration) async {
    for (final (index, clip) in declaration.clips.indexed) {
      final path = clip.filePath;
      if (path == null) continue;
      final file = File(path);
      final extension = path.split('.').last.toLowerCase();
      final type = _clipTypes[extension] ?? 'video/mp4';
      try {
        final size = await file.length();
        final created = await _api.post('/v1/jobs/$jobId/clips', {
          'index': index,
          'contentType': type,
          'sizeBytes': size,
        });
        final sessionUri = await _openSession(
          Uri.parse(created['uploadUrl'] as String),
          type,
          size,
        );
        await _gcs.put<void>(
          sessionUri,
          data: file.openRead(),
          options: Options(
            headers: {
              'Content-Range': chunkRange(0, size - 1, size),
              Headers.contentLengthHeader: size,
            },
          ),
        );
      } on ApiException catch (e) {
        throw UploadException(_failureFor(e));
      } on DioException catch (e) {
        throw UploadException(_gcsFailure(e));
      } on FileSystemException {
        throw const UploadException(UploadRejected('clip_unreadable'));
      }
    }
  }

  @override
  Future<void> discard(UploadSession session) async {
    final stored = _sessions.remove(session.jobId);
    await _store.clear();
    if (stored != null) {
      // GCS answers a cancelled session with 499; nothing to check.
      unawaited(
        _gcs
            .delete<void>(
              stored.sessionUri,
              options: Options(validateStatus: (_) => true),
            )
            .then((_) {}, onError: (Object _) {}),
      );
    }
    try {
      await _api.delete('/v1/jobs/${session.jobId}');
    } on ApiException catch (e) {
      log('Discard failed: ${e.code}');
    }
  }

  StoredUpload _require(String jobId) {
    final stored = _sessions[jobId];
    if (stored == null) throw const UploadException(UploadExpired());
    return stored;
  }

  static String _mimeFor(PickedVideo video) => switch (video.container.name) {
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    _ => 'video/mp4',
  };

  static UploadFailure _failureFor(ApiException e) {
    if (e.retryable) return const UploadNetworkError();
    return UploadRejected(e.code);
  }

  /// Network trouble, 5xx, 408 and 429 retry; a gone session (404, 410)
  /// needs a fresh one; any other 4xx is final.
  static UploadFailure _gcsFailure(DioException e) {
    final status = e.response?.statusCode;
    if (status == null) return const UploadNetworkError();
    if (status == 404 || status == 410) return const UploadExpired();
    if (status >= 500 || status == 408 || status == 429) {
      return const UploadNetworkError();
    }
    return UploadRejected('storage_$status');
  }
}
