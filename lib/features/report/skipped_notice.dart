import 'package:contextlens/core/theme/colors.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/widgets/app_card.dart';
import 'package:contextlens/features/report/flag_presentation.dart';
import 'package:contextlens/features/report/models.dart';
import 'package:flutter/material.dart';

/// Says which checks couldn't run, so a short report is never read as a
/// clean one.
class SkippedNotice extends StatelessWidget {
  const SkippedNotice({required this.skipped, super.key});

  final List<String> skipped;

  static String copy(List<String> skipped) {
    final names = [
      for (final name in skipped)
        FlagCategory.values
            .firstWhere(
              (c) => c.name == name,
              orElse: () => FlagCategory.unknown,
            )
            .label,
    ];
    final list = names.length == 1
        ? names.single
        : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
    return "$list couldn't run this time. Run the check again to include it.";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    return AppCard(
      borderColor: colors.insufficientEvidence,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: colors.insufficientEvidence),
          const SizedBox(width: Spacing.space3),
          Expanded(
            child: Text(copy(skipped), style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
