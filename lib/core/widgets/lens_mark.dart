import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The ContextLens mark: a lens ring with a highlight arc. The intro
/// animates [ring], [scan] and [glint]; the static mark has ring and glint
/// at 1 and no scan line.
class LensMarkPainter extends CustomPainter {
  const LensMarkPainter({
    required this.color,
    this.ring = 1,
    this.scan = 0,
    this.glint = 1,
    this.opacity = 1,
  });

  final Color color;
  final double ring;
  final double scan;
  final double glint;
  final double opacity;

  // Proportions of the canvas side, shared with the native splash image.
  static const double _radius = 0.40;
  static const double _stroke = 0.085;
  static const double _glintRadius = 0.58;
  static const double _glintStart = math.pi * 1.08;
  static const double _glintSweep = math.pi * 0.34;
  static const double _scanStroke = 0.035;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final center = size.center(Offset.zero);
    final r = side * _radius;
    final stroke = side * _stroke;
    final base = color.withValues(alpha: color.a * opacity);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..color = base;

    if (ring > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        -math.pi / 2,
        math.pi * 2 * ring.clamp(0, 1),
        false,
        paint,
      );
    }

    if (glint > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r * _glintRadius),
        _glintStart,
        _glintSweep * glint.clamp(0, 1),
        false,
        paint
          ..strokeWidth = stroke * 0.75
          ..color = base.withValues(alpha: base.a * 0.7),
      );
    }

    if (scan > 0 && scan < 1) {
      // The line travels top to bottom inside the ring and fades at both ends.
      final inner = r - stroke;
      final dy = -inner + 2 * inner * scan;
      final half = math.sqrt(math.max(0, inner * inner - dy * dy));
      final y = center.dy + dy;
      canvas.drawLine(
        Offset(center.dx - half, y),
        Offset(center.dx + half, y),
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = side * _scanStroke
          ..color = base.withValues(alpha: base.a * math.sin(math.pi * scan)),
      );
    }
  }

  @override
  bool shouldRepaint(LensMarkPainter old) =>
      old.color != color ||
      old.ring != ring ||
      old.scan != scan ||
      old.glint != glint ||
      old.opacity != opacity;
}

class LensMark extends StatelessWidget {
  const LensMark({this.size = 28, this.color, super.key});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: LensMarkPainter(
          color: color ?? Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
