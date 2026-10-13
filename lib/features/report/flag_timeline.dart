import 'package:contextlens/core/theme/colors.dart';
import 'package:contextlens/core/theme/motion.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/utils/formatters.dart';
import 'package:contextlens/features/report/flag_presentation.dart';
import 'package:contextlens/features/report/models.dart';
import 'package:contextlens/features/report/playback.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A track the length of the video with one marker per issue, colored and
/// iconed by category, plus the playhead. Markers drop in staggered on
/// first show.
class FlagTimeline extends StatelessWidget {
  const FlagTimeline({
    required this.flags,
    required this.durationMs,
    required this.playback,
    required this.selectedId,
    required this.onSelect,
    required this.reveal,
    super.key,
  });

  final List<Flag> flags;
  final int durationMs;
  final ValueListenable<PlaybackState> playback;
  final String? selectedId;
  final ValueChanged<Flag> onSelect;

  /// Play the drop-in stagger (first view of this report only).
  final bool reveal;

  static const double height = 56;
  static const double _marker = 14;
  static const double _selected = 22;
  static const double _hit = 48;
  static const int _maxStaggered = 8;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = AppColors.of(context);
    final motion = Motion.of(context);
    final total = durationMs <= 0 ? 1 : durationMs;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth - 2 * Spacing.screen;
          double xFor(int ms) =>
              Spacing.screen + width * (ms / total).clamp(0.0, 1.0);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: Spacing.screen,
                right: Spacing.screen,
                top: height / 2 - 1.5,
                height: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(Radii.full),
                    ),
                  ),
                ),
              ),
              RepaintBoundary(
                child: ValueListenableBuilder<PlaybackState>(
                  valueListenable: playback,
                  builder: (context, state, _) {
                    final ms = state.position.inMilliseconds;
                    return Stack(
                      children: [
                        Positioned(
                          left: Spacing.screen,
                          width: xFor(ms) - Spacing.screen,
                          top: height / 2 - 1.5,
                          height: 3,
                          child: ColoredBox(color: scheme.primary),
                        ),
                        Positioned(
                          left: xFor(ms) - 1,
                          top: Spacing.space2,
                          bottom: Spacing.space2,
                          width: 2,
                          child: ColoredBox(color: scheme.onSurface),
                        ),
                      ],
                    );
                  },
                ),
              ),
              for (final (i, flag) in flags.indexed)
                Positioned(
                  left: xFor(flag.startMs) - _hit / 2,
                  top: (height - _hit) / 2,
                  width: _hit,
                  height: _hit,
                  child:
                      _Marker(
                        flag: flag,
                        color: flag.category.color(colors),
                        selected: flag.id == selectedId,
                        onTap: () => onSelect(flag),
                      )._dropIn(
                        enabled: reveal && !motion.reduced && i < _maxStaggered,
                        index: i,
                      ),
                ),
            ],
          );
        },
      ),
    );
  }
}

extension on Widget {
  Widget _dropIn({required bool enabled, required int index}) {
    if (!enabled) return this;
    return animate(delay: Duration(milliseconds: 40 * index)).scale(
      begin: Offset.zero,
      end: const Offset(1, 1),
      duration: Durations.short4 + const Duration(milliseconds: 50),
      curve: Curves.easeOutBack,
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({
    required this.flag,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Flag flag;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = Motion.of(context);
    final size = selected ? FlagTimeline._selected : FlagTimeline._marker;
    final severity = flag.severity?.label.toLowerCase();

    return Semantics(
      button: true,
      selected: selected,
      label: [
        '${flag.category.label} flag at ${formatDurationMs(flag.startMs)}',
        ?severity,
      ].join(', '),
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: FlagTimeline._hit / 2,
        child: Center(
          child: AnimatedContainer(
            duration: motion.short4,
            curve: Motion.standard,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? scheme.onSurface : scheme.surface,
                width: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
