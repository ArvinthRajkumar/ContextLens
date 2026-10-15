import 'package:contextlens/core/utils/formatters.dart';
import 'package:contextlens/features/upload/upload_controller.dart';
import 'package:contextlens/features/upload/upload_repository.dart';

/// The one place upload states and failures become user copy.
extension UploadFailureCopy on UploadFailure {
  String get message => switch (this) {
    UploadNetworkError() => 'The connection dropped.',
    UploadExpired() => 'The upload link expired. Start the upload again.',
    UploadRejected(:final code) => switch (code) {
      'daily_limit' => 'Daily limit reached, try again tomorrow.',
      'too_many_running' =>
        'You have 3 checks running. Wait for one to finish, then try again.',
      'busy' => 'ContextLens is busy, try later.',
      'too_large' => 'Videos can be up to 200 MB.',
      'video_too_long' => 'Videos can be up to 3 minutes long.',
      _ => "The server didn't accept this upload.",
    },
  };
}

/// "about 24 s left", "about 3 min left".
String formatTimeLeft(Duration left) {
  final seconds = left.inSeconds;
  if (seconds < 60) return 'about ${seconds < 1 ? 1 : seconds} s left';
  return 'about ${(seconds / 60).ceil()} min left';
}

/// "3.2 MB/s".
String formatSpeed(double bytesPerSecond) =>
    '${formatBytes(bytesPerSecond.round())}/s';

extension UploadStateCopy on UploadState {
  /// One short status line for the current phase.
  String status(DateTime now) => switch (phase) {
    UploadPhase.preparing => 'Getting ready',
    UploadPhase.uploading => 'Uploading',
    UploadPhase.paused => 'Paused',
    UploadPhase.waitingForNetwork => 'Waiting for connection, upload paused',
    UploadPhase.retrying => _retryLine(now),
    UploadPhase.failed => failure?.message ?? 'Upload failed.',
    UploadPhase.submitting => 'Starting checks',
    UploadPhase.done => 'Uploaded',
    UploadPhase.cancelled => 'Upload cancelled',
  };

  String _retryLine(DateTime now) {
    final at = retryAt;
    final seconds = at == null ? 0 : at.difference(now).inSeconds + 1;
    final reason = failure?.message ?? 'The upload stopped.';
    return seconds <= 0 ? '$reason Retrying' : '$reason Retrying in $seconds s';
  }
}
