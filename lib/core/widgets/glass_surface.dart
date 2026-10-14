import 'package:contextlens/core/theme/colors.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:flutter/material.dart';

/// The liquid glass look shared by every card: a diagonal fill that is
/// brightest at the top left, and a hairline edge that catches the light
/// there and fades toward the bottom right. [tint] replaces the fill with a
/// flat color (an accent card); [faint] steps the glass back.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    required this.child,
    this.tint,
    this.faint = false,
    this.edge,
    this.borderRadius = Radii.card,
    super.key,
  });

  final Widget child;
  final Color? tint;
  final bool faint;

  /// Overrides the light edge with a flat color, for example an error.
  final Color? edge;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final tint = this.tint;
    final base = faint ? colors.glassFaint : colors.glass;

    return CustomPaint(
      foregroundPainter: _EdgePainter(
        radius: borderRadius,
        lit: edge ?? colors.glassBorder,
        faded: edge ?? colors.glassEdgeFade,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color: tint,
          gradient: tint != null
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [faint ? base : colors.glassSheen, base],
                ),
        ),
        child: child,
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  const _EdgePainter({
    required this.radius,
    required this.lit,
    required this.faded,
  });

  final BorderRadius radius;
  final Color lit;
  final Color faded;

  static const double _width = 1;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect.deflate(_width / 2));
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _width
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [lit, faded],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.lit != lit || old.faded != faded || old.radius != radius;
}
