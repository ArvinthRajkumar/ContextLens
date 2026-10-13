import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/widgets/info_pill.dart';
import 'package:contextlens/features/report/flag_presentation.dart';
import 'package:contextlens/features/report/models.dart';
import 'package:flutter/material.dart';

/// The exact clause a compliance flag rests on, plus whether it is a
/// self-regulatory code or the law. Renders nothing for a citation that
/// isn't a rule.
class ClauseChips extends StatelessWidget {
  const ClauseChips({required this.citation, super.key});

  final Citation? citation;

  @override
  Widget build(BuildContext context) {
    final citation = this.citation;
    final label = citation?.clauseLabel;
    if (citation == null || label == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final authority = citation.authority ?? Authority.unknown;

    return Wrap(
      spacing: Spacing.space2,
      runSpacing: Spacing.space1,
      children: [
        InfoPill(
          icon: Icons.menu_book_outlined,
          label: label,
          color: scheme.onSurface,
          semanticsLabel: 'Rule: $label',
        ),
        InfoPill(
          icon: authority.icon,
          label: authority.label,
          color: scheme.onSurfaceVariant,
        ),
      ],
    );
  }
}
