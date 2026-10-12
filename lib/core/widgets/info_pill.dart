import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/theme/typography.dart';
import 'package:flutter/material.dart';

/// Small tinted pill: an icon plus a short label in the same color.
/// Always pair a color with an icon and text, never color alone.
class InfoPill extends StatelessWidget {
  const InfoPill({
    required this.icon,
    required this.label,
    required this.color,
    this.semanticsLabel,
    this.mono = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String? semanticsLabel;

  /// Use tabular digits, for counts.
  final bool mono;

  static const double _iconSize = 14;
  static const double _tint = 0.12;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.labelMedium;
    final style = (mono ? AppTypography.monoOf(base) : base)?.copyWith(
      color: color,
    );

    return Semantics(
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: _tint),
          borderRadius: const BorderRadius.all(Radius.circular(Radii.full)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.space2,
            vertical: Spacing.space1,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: _iconSize, color: color),
              const SizedBox(width: Spacing.space1),
              Flexible(child: Text(label, style: style)),
            ],
          ),
        ),
      ),
    );
  }
}
