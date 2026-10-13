import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/theme/typography.dart';
import 'package:contextlens/core/utils/formatters.dart';
import 'package:contextlens/features/report/playback.dart';
import 'package:flutter/material.dart';

/// The report's video, letterboxed on a dark band, with tap to play or
/// pause and a mono timecode. Only the overlay listens to playback ticks;
/// the video surface itself never rebuilds on progress.
class ReportVideo extends StatelessWidget {
  const ReportVideo({required this.player, required this.height, super.key});

  final ReportPlayer player;
  final double height;

  static const _band = Color(0xFF05080B);
  static const _onBand = Color(0xFFFFFFFF);
  static const _scrim = Color(0x8C000000);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: height,
      child: ColoredBox(
        color: _band,
        child: ValueListenableBuilder<PlaybackState>(
          valueListenable: player.state,
          builder: (context, state, video) {
            if (state.hasError) {
              return const Center(
                child: Text(
                  "Couldn't play this video.",
                  style: TextStyle(color: _onBand),
                ),
              );
            }
            if (!state.isReady) {
              return const Center(child: CircularProgressIndicator());
            }
            return Semantics(
              button: true,
              label: state.isPlaying ? 'Pause video' : 'Play video',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: state.isPlaying ? player.pause : player.play,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: AspectRatio(
                        aspectRatio: state.aspectRatio,
                        child: video,
                      ),
                    ),
                    if (!state.isPlaying)
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          color: _scrim,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(Spacing.space3),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: _onBand,
                            size: 32,
                          ),
                        ),
                      ),
                    Positioned(
                      right: Spacing.space3,
                      bottom: Spacing.space2,
                      child: Text(
                        '${formatDurationMs(state.position.inMilliseconds)}'
                        ' / ${formatDurationMs(state.duration.inMilliseconds)}',
                        style: AppTypography.monoOf(theme.textTheme.labelMedium)
                            .copyWith(color: _onBand),
                        // An overlay on the picture: grows a little, never
                        // enough to cover it.
                        textScaler: MediaQuery.textScalerOf(context)
                            .clamp(maxScaleFactor: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          child: RepaintBoundary(child: player.buildView()),
        ),
      ),
    );
  }
}
