import 'package:contextlens/core/theme/colors.dart';
import 'package:contextlens/core/theme/motion.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/features/report/flag_presentation.dart';
import 'package:contextlens/features/report/models.dart';
import 'package:flutter/material.dart';

/// A category count in the report summary. Tapping it brings that
/// category's flags to the top; tapping it again restores the order.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    required this.category,
    required this.count,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final FlagCategory category;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  static const double _iconSize = 16;
  static const double _tint = 0.12;
  static const double _selectedTint = 0.24;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = category.color(AppColors.of(context));
    final motion = Motion.of(context);

    return Semantics(
      button: true,
      selected: selected,
      label:
          '$count ${category.label.toLowerCase()} '
          '${count == 1 ? 'flag' : 'flags'}',
      hint: selected ? 'Shows flags in the usual order' : 'Shows these first',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: AnimatedContainer(
            duration: motion.short4,
            curve: Motion.standard,
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.space3,
              vertical: Spacing.space2,
            ),
            decoration: ShapeDecoration(
              color: color.withValues(alpha: selected ? _selectedTint : _tint),
              shape: StadiumBorder(
                side: BorderSide(
                  color: selected ? color : Colors.transparent,
                  width: 1.5,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? Icons.check : category.icon,
                  size: _iconSize,
                  color: color,
                ),
                const SizedBox(width: Spacing.space1),
                Flexible(
                  child: Text(
                    // "Claims 2" reads right for every category; "2 claims"
                    // breaks for "fact check" and singulars.
                    '${category.label} $count',
                    style: theme.textTheme.labelLarge?.copyWith(color: color),
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
