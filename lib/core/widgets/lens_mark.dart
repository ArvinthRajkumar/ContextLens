import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Geometry of the ContextLens mark, as fractions of the canvas side. The
/// app logo, splash, launcher icons and docs/brand/lens_mark.svg are all
/// drawn from these numbers (see tool/render_brand_test.dart).
abstract final class LensGeometry {
  /// Ring outer diameter is 58% of the canvas.
  static const double ringOuter = 0.29;
  static const double ringStroke = 0.065;
  static const double ringRadius = ringOuter - ringStroke / 2;

  static const double glintRadius = 0.17;
  static const double glintStroke = 0.035;
  static const double glintStart = math.pi * 1.1;
  static const double glintSweep = math.pi * 0.36;

  /// The resting scan line sits slightly below center.
  static const double scanY = 0.015;
  static const double scanStroke = 0.012;
  // Short enough that the right end clears the badge cut-out.
  static const double scanInset = 0.055;
  static const double scanOpacity = 0.6;

  /// Badge at about 4 o'clock, centered on the ring, 30% of its diameter.
  static const double badgeAngle = math.pi / 6;
  static const double badgeRadius = ringOuter * 0.3;
  static const double badgeGap = 0.03;
  static const double checkStroke = 0.022;

  static Offset badgeCenter(Offset center, double side) =>
      center +
      Offset(math.cos(badgeAngle), math.sin(badgeAngle)) * ringRadius * side;

  /// Farthest painted point from the center: the badge's outer edge.
  static const double extent = ringRadius + badgeRadius;
}

/// The ContextLens mark: a flat lens ring with a highlight arc, a scan line
/// and a verified badge cut out from the ring.
///
/// The intro animates [ring], [scan], [glint] and [badge]; the static mark
/// has all four at 1. The badge gap and checkmark are punched out, so they
/// show whatever is behind the mark.
class LensMarkPainter extends CustomPainter {
  const LensMarkPainter({
    required this.color,
    required this.highlight,
    this.ring = 1,
    this.scan = 1,
    this.glint = 1,
    this.badge = 1,
    this.opacity = 1,
  });

  final Color color;
  final Color highlight;
  final double ring;

  /// 0 to 1: the scan line sweeps down from the top of the lens and comes
  /// to rest just below center.
  final double scan;
  final double glint;

  /// Badge scale, 0 to 1 (may overshoot with an ease-out-back curve).
  final double badge;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final center = size.center(Offset.zero);
    Color fade(Color c, [double a = 1]) =>
        c.withValues(alpha: c.a * a * opacity);

    canvas.saveLayer(Offset.zero & size, Paint());

    if (ring > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: LensGeometry.ringRadius * side),
        -math.pi / 2,
        math.pi * 2 * ring.clamp(0, 1),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = LensGeometry.ringStroke * side
          ..color = fade(color),
      );
    }

    if (glint > 0) {
      canvas.drawArc(
        Rect.fromCircle(
          center: center,
          radius: LensGeometry.glintRadius * side,
        ),
        LensGeometry.glintStart,
        LensGeometry.glintSweep * glint.clamp(0, 1),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = LensGeometry.glintStroke * side
          ..color = fade(highlight),
      );
    }

    if (scan > 0) {
      final inner =
          (LensGeometry.ringOuter -
              LensGeometry.ringStroke -
              LensGeometry.scanInset) *
          side;
      final rest = LensGeometry.scanY * side;
      final t = scan.clamp(0.0, 1.0);
      final dy = -inner + (rest + inner) * t;
      final half = math.sqrt(math.max(0, inner * inner - dy * dy));
      canvas.drawLine(
        Offset(center.dx - half, center.dy + dy),
        Offset(center.dx + half, center.dy + dy),
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = LensGeometry.scanStroke * side
          ..color = fade(color, LensGeometry.scanOpacity * math.min(1, t * 4)),
      );
    }

    if (badge > 0) _paintBadge(canvas, center, side, fade(color));

    canvas.restore();
  }

  void _paintBadge(Canvas canvas, Offset center, double side, Color fill) {
    final at = LensGeometry.badgeCenter(center, side);
    final r = LensGeometry.badgeRadius * side * badge;
    final clear = Paint()..blendMode = BlendMode.clear;

    // A clear ring around the badge keeps it from fusing with the lens.
    canvas
      ..drawCircle(at, r + LensGeometry.badgeGap * side * badge, clear)
      ..drawCircle(at, r, Paint()..color = fill);

    final unit = r / LensGeometry.badgeRadius / side;
    final s = r;
    final check = Path()
      ..moveTo(at.dx - s * 0.42, at.dy + s * 0.02)
      ..lineTo(at.dx - s * 0.12, at.dy + s * 0.32)
      ..lineTo(at.dx + s * 0.44, at.dy - s * 0.28);
    canvas.drawPath(
      check,
      Paint()
        ..blendMode = BlendMode.clear
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = LensGeometry.checkStroke * side * unit,
    );
  }

  @override
  bool shouldRepaint(LensMarkPainter old) =>
      old.color != color ||
      old.highlight != highlight ||
      old.ring != ring ||
      old.scan != scan ||
      old.glint != glint ||
      old.badge != badge ||
      old.opacity != opacity;
}

class LensMark extends StatelessWidget {
  const LensMark({this.size = 36, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: LensMarkPainter(
          color: scheme.primary,
          // The brand highlight is a pale tint; on the light sky a
          // translucent primary keeps the arc visible.
          highlight: scheme.primary.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
