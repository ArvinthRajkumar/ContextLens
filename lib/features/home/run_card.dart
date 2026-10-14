import 'package:animations/animations.dart';
import 'package:contextlens/core/theme/colors.dart';
import 'package:contextlens/core/theme/motion.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/utils/formatters.dart';
import 'package:contextlens/core/widgets/app_background.dart';
import 'package:contextlens/core/widgets/app_card.dart';
import 'package:contextlens/core/widgets/info_pill.dart';
import 'package:contextlens/core/widgets/video_thumbnail.dart';
import 'package:contextlens/features/report/flag_presentation.dart';
import 'package:contextlens/features/report/models.dart';
import 'package:contextlens/features/report/report_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A recent run. Opens its report with a container transform, or the live
/// stages while the check is still running.
class RunCard extends StatelessWidget {
  const RunCard({required this.job, super.key});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final motion = Motion.of(context);

    if (job.isActive) {
      return AppCard(
        padding: EdgeInsets.zero,
        onTap: () => context.push('/run/${job.id}'),
        child: _RunCardContent(job: job),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: Radii.card,
        boxShadow: colors.cardShadows,
      ),
      child: OpenContainer<void>(
        transitionDuration: motion.reduced
            ? Durations.short4
            : Durations.medium4,
        transitionType: motion.reduced
            ? ContainerTransitionType.fadeThrough
            : ContainerTransitionType.fade,
        closedColor: colors.glass,
        openColor: theme.colorScheme.surface,
        middleColor: theme.colorScheme.surface,
        closedElevation: 0,
        openElevation: 0,
        closedShape: RoundedRectangleBorder(
          borderRadius: Radii.card,
          side: BorderSide(color: colors.glassBorder),
        ),
        closedBuilder: (context, _) => _RunCardContent(job: job),
        openBuilder: (context, _) =>
            AppBackground(child: ReportPage(jobId: job.id)),
      ),
    );
  }
}

class _RunCardContent extends StatelessWidget {
  const _RunCardContent({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = [
      formatRunDate(job.createdAt),
      if (job.version > 1) 'Run ${job.version}',
    ].join('  ·  ');

    return Padding(
      padding: const EdgeInsets.all(Spacing.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VideoThumbnail(durationMs: job.video?.durationMs),
          const SizedBox(width: Spacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.title ?? 'Untitled video',
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Spacing.space1),
                Text(
                  meta,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Spacing.space3),
                _RunStatus(job: job),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RunStatus extends StatelessWidget {
  const _RunStatus({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = AppColors.of(context);
    final comparison = job.comparison;
    final counts = job.issueCounts;

    final pills = <Widget>[
      if (job.status == JobStatus.failed)
        InfoPill(
          icon: Icons.error_outline,
          label: 'Check failed',
          color: scheme.error,
        )
      else if (job.isActive)
        InfoPill(
          icon: Icons.autorenew,
          label: 'Checking',
          color: scheme.primary,
        )
      else ...[
        if (comparison != null)
          InfoPill(
            icon: Icons.check_circle_outline,
            label:
                '${comparison.resolved} of '
                '${comparison.resolved + comparison.remaining} resolved',
            color: colors.supported,
          ),
        if (counts.isEmpty)
          InfoPill(
            icon: Icons.check_circle_outline,
            label: 'No issues found',
            color: colors.supported,
          ),
        for (final MapEntry(key: category, value: count) in counts.entries)
          InfoPill(
            icon: category.icon,
            label: '$count',
            mono: true,
            color: category.color(colors),
            semanticsLabel:
                '$count ${category.label.toLowerCase()} '
                '${count == 1 ? 'flag' : 'flags'}',
          ),
      ],
    ];

    return Wrap(
      spacing: Spacing.space2,
      runSpacing: Spacing.space2,
      children: pills,
    );
  }
}
