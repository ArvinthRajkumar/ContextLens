import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

/// Where a report's video plays from.
sealed class PlaybackSource {
  const PlaybackSource();
}

/// A bundled asset (mock mode).
final class AssetPlayback extends PlaybackSource {
  const AssetPlayback(this.asset);

  final String asset;
}

/// The creator's local copy, while it is still in the app cache.
final class FilePlayback extends PlaybackSource {
  const FilePlayback(this.path);

  final String path;
}

/// A short-lived signed URL from GET /v1/jobs/{jobId}/video-url.
final class NetworkPlayback extends PlaybackSource {
  const NetworkPlayback(this.url);

  final Uri url;
}

@immutable
class PlaybackState {
  const PlaybackState({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isPlaying = false,
    this.isReady = false,
    this.hasError = false,
    this.aspectRatio = 9 / 16,
    this.buffered = Duration.zero,
  });

  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool isReady;
  final bool hasError;
  final double aspectRatio;

  /// How far the video has loaded, for the seek bar.
  final Duration buffered;
}

/// The report's video. Position changes go through [state], so widgets that
/// only need the playhead can listen without rebuilding the video surface.
abstract interface class ReportPlayer {
  ValueListenable<PlaybackState> get state;

  Future<void> initialize();

  Future<void> seekTo(Duration position);

  Future<void> play();

  Future<void> pause();

  Widget buildView();

  Future<void> dispose();
}

class VideoReportPlayer implements ReportPlayer {
  VideoReportPlayer(PlaybackSource source)
    : _controller = switch (source) {
        AssetPlayback(:final asset) => VideoPlayerController.asset(asset),
        FilePlayback(:final path) => VideoPlayerController.file(File(path)),
        NetworkPlayback(:final url) => VideoPlayerController.networkUrl(url),
      };

  final VideoPlayerController _controller;
  final _state = ValueNotifier(const PlaybackState());

  @override
  ValueListenable<PlaybackState> get state => _state;

  @override
  Future<void> initialize() async {
    _controller.addListener(_sync);
    try {
      await _controller.initialize();
    } on Object {
      _state.value = const PlaybackState(hasError: true);
      return;
    }
    _sync();
  }

  void _sync() {
    final v = _controller.value;
    _state.value = PlaybackState(
      position: v.position,
      duration: v.duration,
      isPlaying: v.isPlaying,
      isReady: v.isInitialized,
      hasError: v.hasError,
      aspectRatio: v.isInitialized ? v.aspectRatio : 9 / 16,
      buffered: v.buffered.fold(
        Duration.zero,
        (end, range) => range.end > end ? range.end : end,
      ),
    );
  }

  @override
  Future<void> seekTo(Duration position) => _controller.seekTo(position);

  @override
  Future<void> play() => _controller.play();

  @override
  Future<void> pause() => _controller.pause();

  @override
  Widget buildView() => VideoPlayer(_controller);

  @override
  Future<void> dispose() async {
    _controller.removeListener(_sync);
    _state.dispose();
    await _controller.dispose();
  }
}

/// Builds the player for a source. Tests swap in a fake.
final reportPlayerFactoryProvider =
    Provider<ReportPlayer Function(PlaybackSource source)>(
      (ref) => VideoReportPlayer.new,
    );
