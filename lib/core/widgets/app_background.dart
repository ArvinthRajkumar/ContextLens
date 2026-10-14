import 'package:contextlens/core/theme/colors.dart';
import 'package:flutter/material.dart';

/// The sky to white gradient behind every route, with three wide, soft
/// pools of light that the glass cards tint over as they scroll. Routes
/// paint it themselves so a page in transition never shows the one
/// beneath it.
class AppBackground extends StatelessWidget {
  const AppBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(gradient: colors.background),
      child: CustomPaint(painter: _LightPainter(colors.blobs), child: child),
    );
  }
}

/// Static light pools, placed as fractions of the page so every screen
/// size gets the same composition.
class _LightPainter extends CustomPainter {
  const _LightPainter(this.colors);

  final List<Color> colors;

  // (x, y, radius as a fraction of the shorter side) per pool.
  static const _pools = [
    (0.05, 0.18, 0.95),
    (0.95, 0.42, 1.05),
    (0.2, 0.86, 0.9),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    for (final (i, (x, y, r)) in _pools.indexed) {
      final center = Offset(size.width * x, size.height * y);
      final radius = side * r;
      final color = colors[i % colors.length];
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_LightPainter old) => old.colors != colors;
}
