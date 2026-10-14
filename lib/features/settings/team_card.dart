import 'dart:ui';

import 'package:contextlens/core/theme/colors.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/features/settings/fire_text.dart';
import 'package:flutter/material.dart';

/// Who built ContextLens: team Tekken, on fire, on a small dark glass card.
class TeamCard extends StatelessWidget {
  const TeamCard({super.key});

  static const members = ['Arvinth', 'Anju Priya Manam', 'Akash'];
  static const double _blur = 18;
  static const double _nameSize = 44;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyMedium?.copyWith(color: FireColors.onCard);

    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(Radii.lg)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: FireColors.card,
            borderRadius: const BorderRadius.all(Radius.circular(Radii.lg)),
            border: Border.all(color: FireColors.cardBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.space5,
              Spacing.space2,
              Spacing.space5,
              Spacing.space5,
            ),
            child: Column(
              children: [
                FireText(
                  text: 'Tekken',
                  style: (theme.textTheme.displaySmall ?? const TextStyle())
                      .copyWith(
                        fontSize: _nameSize,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                ),
                const SizedBox(height: Spacing.space2),
                Text(
                  members.join('  ·  '),
                  style: body?.copyWith(fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Spacing.space2),
                Text(
                  'Built for Google Cloud AI Builder Cup 2026',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: FireColors.onCardMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
