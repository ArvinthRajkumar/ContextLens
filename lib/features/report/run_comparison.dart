import 'package:contextlens/core/theme/colors.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/widgets/app_card.dart';
import 'package:contextlens/core/widgets/info_pill.dart';
import 'package:contextlens/features/report/models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// "3 of 4 issues resolved" for a re-run, with what is left and anything
/// new, and a way back to the previous run.
class RunComparisonCard extends StatelessWidget {
  const RunComparisonCard({
    required this.comparison,
    required this.previousVersion,
    super.key,
  });

  final RunComparison comparison;
  final int previousVersion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);
    final before = comparison.resolved + comparison.remaining;
    final progress = before == 0 ? 1.0 : comparison.resolved / before;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: colors.supported),
              const SizedBox(width: Spacing.space2),
              Expanded(
                child: Text(
                  '${comparison.resolved} of $before issues resolved',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.space3),
          // The heading above already says this, so the bar is decorative.
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(Radii.full)),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                color: colors.supported,
                backgroundColor: scheme.outlineVariant,
              ),
            ),
          ),
          const SizedBox(height: Spacing.space3),
          Wrap(
            spacing: Spacing.space2,
            runSpacing: Spacing.space2,
            children: [
              InfoPill(
                icon: Icons.check_circle_outline,
                label: '${comparison.resolved} fixed',
                color: colors.supported,
              ),
              if (comparison.remaining > 0)
                InfoPill(
                  icon: Icons.flag_outlined,
                  label: '${comparison.remaining} still open',
                  color: colors.disclosure,
                ),
              if (comparison.newCount > 0)
                InfoPill(
                  icon: Icons.fiber_new_outlined,
                  label: '${comparison.newCount} new',
                  color: colors.claims,
                ),
            ],
          ),
          const SizedBox(height: Spacing.space1),
          TextButton(
            onPressed: () =>
                context.push('/report/${comparison.previousJobId}'),
            child: Text('See run $previousVersion'),
          ),
        ],
      ),
    );
  }
}
