import 'dart:async';

import 'package:animations/animations.dart';
import 'package:contextlens/core/theme/colors.dart';
import 'package:contextlens/core/theme/motion.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/theme/typography.dart';
import 'package:contextlens/core/utils/formatters.dart';
import 'package:contextlens/core/widgets/app_background.dart';
import 'package:contextlens/core/widgets/info_pill.dart';
import 'package:contextlens/features/report/clause_chips.dart';
import 'package:contextlens/features/report/flag_detail_page.dart';
import 'package:contextlens/features/report/flag_presentation.dart';
import 'package:contextlens/features/report/models.dart';
import 'package:flutter/material.dart';

/// One flag in the report list. Tapping it seeks the video there and
/// expands the evidence; "Details" opens the full flag. [pulse] changes
/// when the timeline jumps here, which pulses the border twice.
class FlagCard extends StatefulWidget {
  const FlagCard({
    required this.flag,
    required this.selected,
    required this.pulse,
    required this.onTap,
    required this.onWatch,
    super.key,
  });

  final Flag flag;
  final bool selected;
  final int pulse;
  final VoidCallback onTap;

  /// The creator asked to watch this part from the detail view.
  final VoidCallback onWatch;

  /// Below this height the detail opens as a draggable sheet instead.
  static const double fullPageMinHeight = 600;

  @override
  State<FlagCard> createState() => _FlagCardState();
}

class _FlagCardState extends State<FlagCard>
    with SingleTickerProviderStateMixin {
  static const _pressedScale = 0.98;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: Durations.short4,
  );
  bool _pressed = false;
  bool _expanded = false;

  @override
  void didUpdateWidget(FlagCard old) {
    super.didUpdateWidget(old);
    if (widget.pulse != old.pulse) {
      if (MediaQuery.disableAnimationsOf(context)) return;
      unawaited(_pulse.repeat(reverse: true, count: 2));
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _tap() {
    widget.onTap();
    setState(() => _expanded = !_expanded);
  }

  Future<void> _openSheet() async {
    final watch = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        builder: (context, controller) =>
            FlagDetailContent(flag: widget.flag, scrollController: controller),
      ),
    );
    if (watch ?? false) widget.onWatch();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);
    final motion = Motion.of(context);
    final useSheet =
        MediaQuery.sizeOf(context).height < FlagCard.fullPageMinHeight;
    final restBorder = widget.selected ? scheme.primary : colors.glassBorder;

    return AnimatedScale(
      scale: _pressed ? _pressedScale : 1,
      duration: motion.short2,
      curve: Motion.standard,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: Radii.card,
            boxShadow: colors.cardShadows,
          ),
          child: OpenContainer<bool>(
            // Taps expand the card; only "Details" opens it.
            tappable: false,
            transitionDuration: motion.reduced
                ? Durations.short4
                : Durations.medium4,
            transitionType: motion.reduced
                ? ContainerTransitionType.fadeThrough
                : ContainerTransitionType.fade,
            // Uncertain flags sit a step back from the issues.
            closedColor: widget.flag.uncertain
                ? colors.glassFaint
                : colors.glass,
            openColor: scheme.surface,
            middleColor: scheme.surface,
            closedElevation: 0,
            openElevation: 0,
            closedShape: RoundedRectangleBorder(
              borderRadius: Radii.card,
              side: BorderSide(
                color: Color.lerp(restBorder, scheme.primary, _pulse.value)!,
                width: widget.selected || _pulse.value > 0 ? 2 : 1,
              ),
            ),
            onClosed: (watch) {
              if (watch ?? false) widget.onWatch();
            },
            openBuilder: (context, _) =>
                AppBackground(child: FlagDetailPage(flag: widget.flag)),
            closedBuilder: (context, open) => _CardBody(
              flag: widget.flag,
              expanded: _expanded,
              onTap: _tap,
              onPressed: (pressed) => setState(() => _pressed = pressed),
              onDetails: useSheet ? _openSheet : open,
            ),
          ),
        ),
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.flag,
    required this.expanded,
    required this.onTap,
    required this.onPressed,
    required this.onDetails,
  });

  final Flag flag;
  final bool expanded;
  final VoidCallback onTap;
  final ValueChanged<bool> onPressed;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final motion = Motion.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final label = flag.factLabel;
    final uncertain = flag.uncertain;
    final severity = uncertain ? null : flag.severity;
    final accent = uncertain
        ? theme.colorScheme.onSurfaceVariant
        : flag.category.color(colors);

    // OpenContainer moves this body into its route while animating, outside
    // any Material, so it brings its own for the ink.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        onTapDown: (_) => onPressed(true),
        onTapUp: (_) => onPressed(false),
        onTapCancel: () => onPressed(false),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(flag.category.icon, color: accent),
                  const SizedBox(width: Spacing.space3),
                  Expanded(
                    child: Text(
                      flag.title,
                      style: uncertain
                          ? theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            )
                          : theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: Spacing.space2),
                  Text(
                    formatDurationMs(flag.startMs),
                    style: AppTypography.monoOf(theme.textTheme.labelLarge),
                    semanticsLabel: 'at ${formatDurationMs(flag.startMs)}',
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(
                  left: Spacing.space8 + Spacing.space1,
                  top: Spacing.space2,
                ),
                child: Wrap(
                  spacing: Spacing.space2,
                  runSpacing: Spacing.space1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      [flag.category.label, ?severity?.label].join('  ·  '),
                      style: muted,
                    ),
                    if (uncertain)
                      InfoPill(
                        icon: UncertainPresentation.icon,
                        label: UncertainPresentation.label,
                        color: colors.insufficientEvidence,
                      )
                    else if (label != null)
                      InfoPill(
                        icon: label.icon,
                        label: label.label,
                        color: label.color(colors),
                      ),
                  ],
                ),
              ),
              if (flag.citation?.clauseLabel != null)
                Padding(
                  padding: const EdgeInsets.only(
                    left: Spacing.space8 + Spacing.space1,
                    top: Spacing.space2,
                  ),
                  child: ClauseChips(citation: flag.citation),
                ),
              AnimatedSize(
                duration: motion.medium2,
                curve: Motion.standard,
                alignment: Alignment.topCenter,
                child: expanded
                    ? Padding(
                        padding: const EdgeInsets.only(
                          left: Spacing.space8 + Spacing.space1,
                          top: Spacing.space3,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              flag.evidence,
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: Spacing.space3),
                            Text(
                              'Suggested fix',
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: Spacing.space1),
                            Text(
                              flag.suggestedFix,
                              style: theme.textTheme.bodyMedium,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: onDetails,
                                icon: const Icon(Icons.open_in_full, size: 18),
                                label: const Text('Details'),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
