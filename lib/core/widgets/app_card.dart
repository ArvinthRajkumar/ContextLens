import 'dart:ui';

import 'package:contextlens/core/theme/colors.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/widgets/glass_surface.dart';
import 'package:flutter/material.dart';

/// Liquid glass card ([GlassSurface]) with a soft shadow and an ink ripple.
/// [blur] adds a backdrop blur; keep it for cards over moving content
/// (video, a scrolled list), since it costs a pass per card.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Spacing.space4),
    this.color,
    this.borderColor,
    this.faint = false,
    this.blur = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// A flat tint instead of the glass gradient, for an accent card.
  final Color? color;

  /// Overrides the light edge, for example to mark an error.
  final Color? borderColor;
  final bool faint;
  final bool blur;

  static const double _blurSigma = 20;

  @override
  Widget build(BuildContext context) {
    Widget card = ClipRRect(
      borderRadius: Radii.card,
      child: GlassSurface(
        tint: color,
        faint: faint,
        edge: borderColor,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
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
        boxShadow: AppColors.of(context).cardShadows,
      ),
      child: card,
    );
  }
}
