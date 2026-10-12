import 'dart:async';
import 'dart:math';

import 'package:contextlens/core/connectivity.dart';
import 'package:contextlens/core/log.dart';
import 'package:contextlens/features/compose/compose_controller.dart';
import 'package:contextlens/features/upload/upload_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum UploadPhase {
  preparing,
  uploading,
  paused,
  waitingForNetwork,
  retrying,
  failed,
  submitting,
  done,
  cancelled;

  /// Bytes are moving or about to move.
  bool get isActive => switch (this) {
    preparing || uploading || retrying || submitting => true,
    _ => false,
  };

  /// The upload hasn't finished and still needs the user or the network.
  bool get isUnfinished => this != done && this != cancelled;
}

@immutable
class UploadState {
  const UploadState({
    required this.submission,
    this.phase = UploadPhase.preparing,
    this.sentBytes = 0,
    this.totalBytes = 0,
    this.bytesPerSecond,
    this.failure,
    this.retryAt,
    this.jobId,
  });

  final ComposeSubmission submission;
  final UploadPhase phase;
  final int sentBytes;
  final int totalBytes;

  /// Smoothed speed, refreshed at most every 500 ms for display.
  final double? bytesPerSecond;
  final UploadFailure? failure;

  /// When the next automatic retry starts.
  final DateTime? retryAt;

  /// Set once the check is submitted.
  final String? jobId;

  double get progress => totalBytes == 0 ? 0 : sentBytes / totalBytes;

  Duration? get timeLeft {
    final speed = bytesPerSecond;
    if (speed == null || speed <= 0 || phase != UploadPhase.uploading) {
      return null;
    }
    return Duration(
      milliseconds: ((totalBytes - sentBytes) / speed * 1000).round(),
    );
  }

  UploadState copyWith({
    UploadPhase? phase,
    int? sentBytes,
    int? totalBytes,
    double? bytesPerSecond,
    bool clearSpeed = false,
    UploadFailure? failure,
    bool clearFailure = false,
    DateTime? retryAt,
    String? jobId,
  }) {
    return UploadState(
      submission: submission,
      phase: phase ?? this.phase,
      sentBytes: sentBytes ?? this.sentBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      bytesPerSecond: clearSpeed
          ? null
          : (bytesPerSecond ?? this.bytesPerSecond),
      failure: clearFailure ? null : (failure ?? this.failure),
      retryAt: retryAt,
      jobId: jobId ?? this.jobId,
    );
  }
}

/// Exponential moving average of transfer speed. [alpha] weights the newest
/// sample; 0.3 keeps the number calm without lagging badly.
double smoothSpeed(double? previous, double sample, {double alpha = 0.3}) =>
    previous == null ? sample : alpha * sample + (1 - alpha) * previous;

/// 1 s, 2 s, 4 s, 8 s plus up to 20% jitter, for attempts 1 to 4.
Duration retryDelay(int attempt, {Random? random}) {
  final base = 1000 * pow(2, attempt - 1);
  final jitter = (random ?? Random()).nextDouble() * 0.2;
  return Duration(milliseconds: (base * (1 + jitter)).round());
}

/// Drives one upload at a time: pause, resume, cancel, automatic retry with
/// backoff, and pausing while offline. Lives app-wide so an upload keeps
/// going after the user leaves the Run screen.
class UploadController extends Notifier<UploadState?> {
  static const maxAttempts = 5;
  static const _displayInterval = Duration(milliseconds: 500);

  UploadSession? _session;
  UploadCancelToken? _cancel;
  Timer? _retryTimer;
  int _attempt = 0;

  // Speed sampling.
  int? _lastBytes;
  DateTime? _lastSample;
  DateTime? _lastDisplay;
  double? _ema;

  UploadRepository get _repository => ref.read(uploadRepositoryProvider);

  @override
  UploadState? build() {
    ref
      ..listen(isOnlineProvider, (_, next) => _onConnectivity(next.value))
      ..onDispose(_stopTransfer);
    return null;
  }

  Future<void> start(ComposeSubmission submission) async {
    _stopTransfer();
    _session = null;
    _attempt = 0;
    state = UploadState(submission: submission);
    try {
      final session = await _repository.createSession(submission.video);
      if (state?.submission != submission) return;
      _session = session;
      state = state!.copyWith(totalBytes: session.totalBytes);
    } on UploadException catch (e) {
      _onFailure(e.failure);
      return;
    } on Object catch (error) {
      // Never leave the screen stuck on "Getting ready".
      log('Upload session failed: ${error.runtimeType}');
      _onFailure(const UploadRejected('session_error'));
      return;
    }
    await _transfer();
  }

  void pause() {
    if (state?.phase != UploadPhase.uploading &&
        state?.phase != UploadPhase.retrying) {
      return;
    }
    _stopTransfer();
    state = state!.copyWith(phase: UploadPhase.paused, clearSpeed: true);
  }

  Future<void> resume() async {
    final phase = state?.phase;
    if (phase != UploadPhase.paused && phase != UploadPhase.failed) return;
    _attempt = 0;
    await _transfer();
  }

  /// Skips the backoff wait.
  Future<void> retryNow() async {
    if (state?.phase != UploadPhase.retrying) return;
    _retryTimer?.cancel();
    await _transfer();
  }

  Future<void> cancel() async {
    _stopTransfer();
    final session = _session;
    _session = null;
    if (state != null) {
      state = state!.copyWith(phase: UploadPhase.cancelled, clearSpeed: true);
    }
    if (session != null) await _repository.discard(session);
  }

  /// Forgets a finished or cancelled upload.
  void clear() {
    if (state?.phase.isUnfinished ?? false) return;
    state = null;
  }

  Future<void> _transfer() async {
    final session = _session;
    final current = state;
    if (session == null || current == null) return;
    if (ref.read(isOnlineProvider).value == false) {
      state = current.copyWith(phase: UploadPhase.waitingForNetwork);
      return;
    }

    _stopTransfer();
    final cancel = _cancel = UploadCancelToken();
    _resetSpeed();
    state = current.copyWith(
      phase: UploadPhase.uploading,
      clearFailure: true,
      clearSpeed: true,
    );

    try {
      final from = await _repository.committedBytes(session);
      await for (final sent in _repository.upload(
        session,
        fromByte: from,
        cancel: cancel,
      )) {
        _onProgress(sent);
      }
    } on UploadException catch (e) {
      if (!cancel.isCancelled) _onFailure(e.failure);
      return;
    }
    if (cancel.isCancelled) return;
    await _submit(session);
  }

  void _onProgress(int sent) {
    final now = DateTime.now();
    final lastBytes = _lastBytes;
    final lastSample = _lastSample;
    if (lastBytes != null && lastSample != null) {
      final seconds = now.difference(lastSample).inMicroseconds / 1e6;
      if (seconds > 0) _ema = smoothSpeed(_ema, (sent - lastBytes) / seconds);
    }
    _lastBytes = sent;
    _lastSample = now;

    final lastDisplay = _lastDisplay;
    final refreshSpeed =
        lastDisplay == null || now.difference(lastDisplay) >= _displayInterval;
    if (refreshSpeed && _ema != null) _lastDisplay = now;
    state = state!.copyWith(
      sentBytes: sent,
      bytesPerSecond: refreshSpeed ? _ema : null,
    );
  }

  void _onFailure(UploadFailure failure) {
    log('Upload failed: ${failure.runtimeType}');
    _attempt++;
    if (failure.isTransient && _attempt < maxAttempts) {
      final delay = retryDelay(_attempt);
      state = state!.copyWith(
        phase: UploadPhase.retrying,
        failure: failure,
        retryAt: DateTime.now().add(delay),
        clearSpeed: true,
      );
      _retryTimer = Timer(delay, _transfer);
    } else {
      state = state!.copyWith(
        phase: UploadPhase.failed,
        failure: failure,
        clearSpeed: true,
      );
    }
  }

  Future<void> _submit(UploadSession session) async {
    final current = state!;
    state = current.copyWith(phase: UploadPhase.submitting, clearSpeed: true);
    try {
      final jobId = await _repository.submit(
        session,
        video: current.submission.video,
        declaration: current.submission.declaration,
        parentJobId: current.submission.parentJobId,
      );
      state = state!.copyWith(phase: UploadPhase.done, jobId: jobId);
    } on UploadException catch (e) {
      _onFailure(e.failure);
    }
  }

  void _onConnectivity(bool? online) {
    final phase = state?.phase;
    if (online == false &&
        (phase == UploadPhase.uploading || phase == UploadPhase.retrying)) {
      _stopTransfer();
      state = state!.copyWith(
        phase: UploadPhase.waitingForNetwork,
        clearSpeed: true,
      );
    } else if (online == true && phase == UploadPhase.waitingForNetwork) {
      unawaited(_transfer());
    }
  }

  void _stopTransfer() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _cancel?.cancel();
    _cancel = null;
  }

  void _resetSpeed() {
    _lastBytes = null;
    _lastSample = null;
    _lastDisplay = null;
    _ema = null;
  }
}

final uploadControllerProvider =
    NotifierProvider<UploadController, UploadState?>(UploadController.new);
