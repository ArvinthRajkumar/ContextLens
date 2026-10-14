import 'package:contextlens/core/theme/colors.dart';
import 'package:contextlens/core/theme/motion.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/theme/typography.dart';
import 'package:contextlens/core/utils/formatters.dart';
import 'package:contextlens/features/report/flag_presentation.dart';
import 'package:contextlens/features/report/models.dart';
import 'package:contextlens/features/report/playback.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The report's seek bar: a thin track (played, buffered, rest), a line
/// playhead, small ticks for each flag, and "0:07 / 0:40" on the right.
/// Drag or tap anywhere to seek; tap a tick to jump to its flag.
class FlagTimeline extends StatefulWidget {
  const FlagTimeline({
    required this.flags,
    required this.durationMs,
    required this.playback,
    required this.selectedId,
    required this.onSelect,
    required this.onSeek,
    this.focus,
    super.key,
  });

  final List<Flag> flags;
  final int durationMs;
  final ValueListenable<PlaybackState> playback;
  final String? selectedId;
  final ValueChanged<Flag> onSelect;
  final ValueChanged<Duration> onSeek;

  /// The category chosen in the summary: its ticks stand out, the rest dim.
  final FlagCategory? focus;

  static const double height = 48;
  static const double track = 3;
  static const double trackActive = 5;
  static const double playhead = 12;
  static const double playheadActive = 18;
  static const double tick = 8;

  /// How close a tap must land to a tick to mean that flag.
  static const double tickHit = 12;

  @override
  State<FlagTimeline> createState() => _FlagTimelineState();
}

class _FlagTimelineState extends State<FlagTimeline> {
  /// While dragging: the position under the finger, as a fraction.
  double? _dragFraction;

  int get _total => widget.durationMs <= 0 ? 1 : widget.durationMs;

  double _fractionAt(double dx, double width) => (dx / width).clamp(0.0, 1.0);

  Duration _at(double fraction) =>
      Duration(milliseconds: (fraction * _total).round());

  Flag? _tickAt(double dx, double width) {
    Flag? best;
    var bestDistance = FlagTimeline.tickHit;
    for (final flag in widget.flags) {
      final x = width * (flag.startMs / _total).clamp(0.0, 1.0);
      final distance = (x - dx).abs();
      if (distance <= bestDistance) {
        best = flag;
        bestDistance = distance;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final motion = Motion.of(context);
    final dragging = _dragFraction != null;

    return SizedBox(
      height: FlagTimeline.height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.screen),
        child: Row(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: Semantics(
                          slider: true,
                          label: 'Seek video',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (details) {
                              final dx = details.localPosition.dx;
                              final flag = _tickAt(dx, width);
                              if (flag != null) {
                                widget.onSelect(flag);
                              } else {
                                widget.onSeek(_at(_fractionAt(dx, width)));
                              }
                            },
                            onHorizontalDragStart: (details) => setState(
                              () => _dragFraction = _fractionAt(
                                details.localPosition.dx,
                                width,
                              ),
                            ),
                            onHorizontalDragUpdate: (details) => setState(
                              () => _dragFraction = _fractionAt(
                                details.localPosition.dx,
                                width,
                              ),
                            ),
                            onHorizontalDragEnd: (_) {
                              final fraction = _dragFraction;
                              setState(() => _dragFraction = null);
                              if (fraction != null) {
                                widget.onSeek(_at(fraction));
                              }
                            },
                            onHorizontalDragCancel: () =>
                                setState(() => _dragFraction = null),
                            child: RepaintBoundary(
                              child: ValueListenableBuilder<PlaybackState>(
                                valueListenable: widget.playback,
                                builder: (context, state, _) {
                                  final played =
                                      _dragFraction ??
                                      (state.position.inMilliseconds / _total)
                                          .clamp(0.0, 1.0);
                                  final buffered =
                                      (state.buffered.inMilliseconds / _total)
                                          .clamp(0.0, 1.0);
                                  return TweenAnimationBuilder<double>(
                                    tween: Tween(end: dragging ? 1 : 0),
                                    duration: motion.short4,
                                    curve: Motion.standard,
                                    builder: (context, grow, _) => Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Positioned.fill(
                                          child: CustomPaint(
                                            painter: SeekBarPainter(
                                              played: played,
                                              buffered: buffered,
                                              grow: grow,
                                              ticks: [
                                                for (final flag in widget.flags)
                                                  SeekTick(
                                                    at: (flag.startMs / _total)
                                                        .clamp(0.0, 1.0),
                                                    color: flag.uncertain
                                                        ? colors
                                                              .insufficientEvidence
                                                        : flag.category.color(
                                                            colors,
                                                          ),
                                                    hollow: flag.uncertain,
                                                    selected:
                                                        flag.id ==
                                                        widget.selectedId,
                                                    dimmed:
                                                        widget.focus != null &&
                                                        flag.category !=
                                                            widget.focus,
                                                  ),
                                              ],
                                              playedColor: colors.seekPlayed,
                                              bufferedColor:
                                                  colors.seekBuffered,
                                              trackColor: colors.seekTrack,
                                              playheadColor:
                                                  theme.colorScheme.onSurface,
                                              ringColor:
                                                  theme.colorScheme.surface,
                                            ),
                                          ),
                                        ),
                                        if (dragging)
                                          _TimeBubble(
                                            left: played * width,
                                            label: formatDurationMs(
                                              _at(played).inMilliseconds,
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      // One accessible button per tick; taps on screen go
                      // through the bar's own gesture handling.
                      for (final flag in widget.flags)
                        Positioned(
                          left:
                              width * (flag.startMs / _total).clamp(0.0, 1.0) -
                              FlagTimeline.tickHit,
                          top: FlagTimeline.height / 2 - FlagTimeline.tickHit,
                          width: 2 * FlagTimeline.tickHit,
                          height: 2 * FlagTimeline.tickHit,
                          child: IgnorePointer(
                            child: _TickSemantics(
                              flag: flag,
                              selected: flag.id == widget.selectedId,
                              onTap: () => widget.onSelect(flag),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: Spacing.space3),
            _TimeLabel(playback: widget.playback, total: _total),
          ],
        ),
      ),
    );
  }
}

class _TickSemantics extends StatelessWidget {
  const _TickSemantics({
    required this.flag,
    required this.selected,
    required this.onTap,
  });

  final Flag flag;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final at = formatDurationMs(flag.startMs);
    final severity = flag.severity?.label.toLowerCase();
    return Semantics(
      button: true,
      selected: selected,
      label: [
        if (flag.uncertain)
          'Uncertain ${flag.category.label.toLowerCase()} flag at $at'
        else
          '${flag.category.label} flag at $at',
        if (!flag.uncertain) ?severity,
      ].join(', '),
      onTap: onTap,
      excludeSemantics: true,
      child: const SizedBox.expand(),
    );
  }
}

@immutable
class SeekTick {
  const SeekTick({
    required this.at,
    required this.color,
    required this.hollow,
    required this.selected,
    required this.dimmed,
  });

  final double at;
  final Color color;
  final bool hollow;
  final bool selected;
  final bool dimmed;

  @override
  bool operator ==(Object other) =>
      other is SeekTick &&
      other.at == at &&
      other.color == color &&
      other.hollow == hollow &&
      other.selected == selected &&
      other.dimmed == dimmed;

  @override
  int get hashCode => Object.hash(at, color, hollow, selected, dimmed);
}

class SeekBarPainter extends CustomPainter {
  const SeekBarPainter({
    required this.played,
    required this.buffered,
    required this.grow,
    required this.ticks,
    required this.playedColor,
    required this.bufferedColor,
    required this.trackColor,
    required this.playheadColor,
    required this.ringColor,
  });

  final double played;
  final double buffered;

  /// 0 at rest, 1 while dragging: the track and playhead thicken.
  final double grow;
  final List<SeekTick> ticks;
  final Color playedColor;
  final Color bufferedColor;
  final Color trackColor;
  final Color playheadColor;
  final Color ringColor;

  static const double _dimmedAlpha = 0.35;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final thickness =
        FlagTimeline.track +
        (FlagTimeline.trackActive - FlagTimeline.track) * grow;
    RRect bar(double from, double to) => RRect.fromLTRBR(
      size.width * from,
      cy - thickness / 2,
      size.width * to,
      cy + thickness / 2,
      Radius.circular(thickness / 2),
    );

    canvas
      ..drawRRect(bar(0, 1), Paint()..color = trackColor)
      ..drawRRect(bar(0, buffered), Paint()..color = bufferedColor)
      ..drawRRect(bar(0, played), Paint()..color = playedColor);

    for (final tick in ticks) {
      final r = FlagTimeline.tick / 2 * (tick.selected ? 1.4 : 1);
      final center = Offset(size.width * tick.at, cy);
      final alpha = tick.dimmed ? _dimmedAlpha : 1.0;
      final color = tick.color.withValues(alpha: tick.color.a * alpha);
      canvas.drawCircle(center, r + 1.5, Paint()..color = ringColor);
      if (tick.hollow) {
        canvas.drawCircle(
          center,
          r - 0.75,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = color,
        );
      } else {
        canvas.drawCircle(center, r, Paint()..color = color);
      }
    }

    final height =
        FlagTimeline.playhead +
        (FlagTimeline.playheadActive - FlagTimeline.playhead) * grow;
    final x = size.width * played;
    canvas.drawRRect(
      RRect.fromLTRBR(
        x - 1,
        cy - height / 2,
        x + 1,
        cy + height / 2,
        const Radius.circular(1),
      ),
      Paint()..color = playheadColor,
    );
  }

  @override
  bool shouldRepaint(SeekBarPainter old) =>
      old.played != played ||
      old.buffered != buffered ||
      old.grow != grow ||
      !listEquals(old.ticks, ticks) ||
      old.playedColor != playedColor ||
      old.bufferedColor != bufferedColor ||
      old.trackColor != trackColor ||
      old.playheadColor != playheadColor ||
      old.ringColor != ringColor;
}

/// The time under the finger, floating above the playhead while dragging.
class _TimeBubble extends StatelessWidget {
  const _TimeBubble({required this.left, required this.label});

  final double left;
  final String label;

  static const double _width = 56;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      left: left - _width / 2,
      bottom: FlagTimeline.height / 2 + FlagTimeline.playheadActive / 2,
      width: _width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.inverseSurface,
          borderRadius: const BorderRadius.all(Radius.circular(Radii.sm)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Spacing.space1),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.monoOf(theme.textTheme.labelMedium)
                .copyWith(color: theme.colorScheme.onInverseSurface),
          ),
        ),
      ),
    );
  }
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel({required this.playback, required this.total});

  final ValueListenable<PlaybackState> playback;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<PlaybackState>(
      valueListenable: playback,
      builder: (context, state, _) => Text(
        '${formatDurationMs(state.position.inMilliseconds)}'
        ' / ${formatDurationMs(total)}',
        style: AppTypography.monoOf(theme.textTheme.labelMedium)
            .copyWith(color: theme.colorScheme.onSurfaceVariant),
        textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.4),
      ),
    );
  }
}
