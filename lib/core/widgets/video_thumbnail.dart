import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/theme/typography.dart';
import 'package:contextlens/core/utils/formatters.dart';
import 'package:flutter/material.dart';

/// Hero tag for the picked video, shared by Compose and Run.
const composeVideoHeroTag = 'compose-video';

/// Portrait video thumbnail with a duration badge. Shows a tonal
/// placeholder until real frame bytes are available.
class VideoThumbnail extends StatelessWidget {
  const VideoThumbnail({
    this.durationMs,
    this.width = 56,
    this.height = 72,
    super.key,
  });

  final int? durationMs;
  final double width;
  final double height;

  static const _badgeColor = Color(0x99000000);
  static const _badgeText = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final duration = durationMs;

    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(Radii.xs)),
        child: SizedBox(
          width: width,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [scheme.surfaceContainerHigh, scheme.primaryContainer],
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: scheme.onSurfaceVariant,
                    size: width * 0.4,
                  ),
                ),
                if (duration != null)
                  Positioned(
                    right: Spacing.space1,
                    bottom: Spacing.space1,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: _badgeColor,
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Text(
                          formatDurationMs(duration),
                          style: AppTypography.monoOf(
                            theme.textTheme.labelSmall,
                          ).copyWith(color: _badgeText),
                          textScaler: TextScaler.noScaling,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
