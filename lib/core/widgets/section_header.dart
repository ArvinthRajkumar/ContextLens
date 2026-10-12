import 'package:contextlens/core/theme/spacing.dart';
import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final action = actionLabel;

    return Padding(
      // An action button makes the row 48dp tall; trim the top padding by
      // the extra height so the title sits at the same rhythm either way.
      padding: EdgeInsets.only(
        top: action == null ? Spacing.space6 : Spacing.space3,
        bottom: action == null ? Spacing.space2 : 0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: text.titleMedium),
            ),
          ),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action)),
        ],
      ),
    );
  }
}
