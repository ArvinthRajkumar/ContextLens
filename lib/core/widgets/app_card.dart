import 'dart:ui';

import 'package:contextlens/core/theme/colors.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:flutter/material.dart';

/// Liquid glass card: translucent white, a white hairline and a soft
/// shadow. [blur] adds a backdrop blur; keep it for cards that sit over
/// moving content (video, a scrolled list), since it costs a pass per card.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Spacing.space4),
    this.color,
    this.borderColor,
    this.blur = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;

  /// Overrides the white hairline, for example to mark an error.
  final Color? borderColor;
  final bool blur;

  static const double _blurSigma = 20;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    Widget card = Material(
      color: color ?? colors.glass,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.card,
        side: BorderSide(color: borderColor ?? colors.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
    if (blur) {
      card = ClipRRect(
        borderRadius: Radii.card,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
          child: card,
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: Radii.card,
        boxShadow: colors.cardShadows,
      ),
      child: card,
    );
  }
}
