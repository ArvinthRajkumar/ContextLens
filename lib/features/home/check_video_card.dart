import 'package:contextlens/core/theme/colors.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/widgets/app_button.dart';
import 'package:contextlens/core/widgets/app_card.dart';
import 'package:contextlens/features/compose/compose_controller.dart';
import 'package:contextlens/features/report/flag_presentation.dart';
import 'package:contextlens/features/report/models.dart';
import 'package:contextlens/features/samples/sample_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The primary entry point on Home.
class CheckVideoCard extends ConsumerWidget {
  const CheckVideoCard({super.key});

  static const _categories = [
    FlagCategory.disclosure,
    FlagCategory.claims,
    FlagCategory.visuals,
    FlagCategory.borrowed,
    FlagCategory.factcheck,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);
    final onCard = scheme.onPrimaryContainer;

    return AppCard(
      color: scheme.primaryContainer,
      padding: const EdgeInsets.all(Spacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Wrap(
              spacing: Spacing.space3,
              children: [
                for (final category in _categories)
                  Icon(category.icon, size: 20, color: category.color(colors)),
              ],
            ),
          ),
          const SizedBox(height: Spacing.space4),
          Text(
            'Check a video before you post',
            style: theme.textTheme.headlineSmall?.copyWith(color: onCard),
          ),
          const SizedBox(height: Spacing.space2),
          Text(
            'We look for missing disclosures, risky claims, borrowed clips '
            "and facts that don't hold up. Takes 1 to 3 minutes.",
            style: theme.textTheme.bodyMedium?.copyWith(color: onCard),
          ),
          const SizedBox(height: Spacing.space5),
          AppButton(
            label: 'Check a video',
            icon: Icons.add,
            expand: true,
            onPressed: () {
              ref.read(composeControllerProvider.notifier).reset();
              context.push('/new');
            },
          ),
          const SizedBox(height: Spacing.space2),
          AppButton(
            label: 'Try a sample video',
            icon: Icons.play_circle_outline,
            variant: AppButtonVariant.secondary,
            expand: true,
            onPressed: () => showSampleSheet(context, openCompose: true),
          ),
        ],
      ),
    );
  }
}
