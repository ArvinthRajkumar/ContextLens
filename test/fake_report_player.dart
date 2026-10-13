import 'package:contextlens/features/report/playback.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A [ReportPlayer] with no platform video, for widget tests.
class FakeReportPlayer implements ReportPlayer {
  FakeReportPlayer(this.source, {this.duration = const Duration(seconds: 94)});

  final PlaybackSource source;
  final Duration duration;
  final seeks = <Duration>[];
  bool playing = false;

  late final _state = ValueNotifier(PlaybackState(duration: duration));

  @override
  ValueListenable<PlaybackState> get state => _state;

  void _set({Duration? position, bool? isPlaying}) {
    final s = _state.value;
    _state.value = PlaybackState(
      position: position ?? s.position,
      duration: duration,
      isPlaying: isPlaying ?? s.isPlaying,
      isReady: true,
    );
  }

  @override
  Future<void> initialize() async => _set();

  @override
  Future<void> seekTo(Duration position) async {
    seeks.add(position);
    _set(position: position);
  }

  @override
  Future<void> play() async {
    playing = true;
    _set(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    playing = false;
    _set(isPlaying: false);
  }

  @override
  Widget buildView() => const SizedBox.expand();

  @override
  Future<void> dispose() async {}
}
