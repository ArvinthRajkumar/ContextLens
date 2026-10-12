import 'package:contextlens/core/theme/spacing.dart';
import 'package:flutter/material.dart';

/// Icon, one line of title, one sentence of body and at most one action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.body,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  static const double _iconSize = 32;
  static const double _badgeSize = 64;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final message = body;
    final cta = action;

    return Padding(
      padding: const EdgeInsets.all(Spacing.space6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _badgeSize,
            height: _badgeSize,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: _iconSize, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Spacing.space4),
          Text(
            title,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: Spacing.space2),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (cta != null) ...[const SizedBox(height: Spacing.space5), cta],
        ],
      ),
    );
  }
}
