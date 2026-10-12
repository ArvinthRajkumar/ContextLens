import 'dart:math' as math;

import 'package:contextlens/core/theme/motion.dart';
import 'package:flutter/material.dart';

/// The upload success moment, driven by one 1200 ms [animation]:
///
///   0 to 200 ms     the full ring tightens to 92%
///   200 to 550 ms   a filled disc expands from it (ease out back)
///   350 to 750 ms   the check draws itself
///   450 to 1170 ms  two ripples spread and fade, 120 ms apart
///   500 to 1100 ms  14 particles burst outward with a little gravity
///
/// At the end only the disc and check remain, so the same widget can then
/// shrink into the first stage dot. Draws outside its box (the ripples and
/// particles), so give it room.
class SuccessBurst extends StatelessWidget {
  const SuccessBurst({
    required this.animation,
    this.reach = SuccessBurstPainter.defaultReach,
    super.key,
  });

  static const total = Duration(milliseconds: 1200);

  final Animation<double> animation;

  /// How far ripples and particles may travel, as a multiple of the disc
  /// radius. Set it so the whole burst stays inside the visible area.
  final double reach;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: CustomPaint(
        painter: SuccessBurstPainter(
          animation: animation,
          reach: reach,
          primary: scheme.primary,
          container: scheme.primaryContainer,
          onPrimary: scheme.onPrimary,
        ),
      ),
    );
  }
}

class SuccessBurstPainter extends CustomPainter {
  SuccessBurstPainter({
    required this.animation,
    required this.primary,
    required this.container,
    required this.onPrimary,
    this.reach = defaultReach,
  }) : super(repaint: animation);

  static const defaultReach = 2.4;

  /// Outer limit for ripples and particles, in disc radii.
  final double reach;

  final Animation<double> animation;
  final Color primary;
  final Color container;

  /// Check and "white" particles. onPrimary keeps 3:1 against the disc in
  /// both themes, where pure white would not on the dark theme's teal.
  final Color onPrimary;

  static const _totalMs = 1200.0;
  static const _particles = 14;
  static const _rippleOpacity = 0.35;
  static const _rippleGap = 120.0;

  // Proportions of the box side, matching the 160dp upload ring.
  static const _ringStroke = 10 / 160;
  static const _checkStroke = 8 / 160;

  /// Progress of [startMs, endMs] at [ms], clamped to 0..1.
  static double _span(double ms, double startMs, double endMs) =>
      ((ms - startMs) / (endMs - startMs)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final ms = animation.value * _totalMs;
    final side = size.shortestSide;
    final center = size.center(Offset.zero);
    final outer = side / 2;
    final ringStroke = side * _ringStroke;

    // Ring tightening, then the disc taking over from it.
    if (ms < 200) {
      final scale = 1 - 0.08 * Motion.exit.transform(_span(ms, 0, 200));
      canvas.drawCircle(
        center,
        (outer - ringStroke / 2) * scale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringStroke
          ..color = primary,
      );
    } else {
      final grow = Curves.easeOutBack.transform(_span(ms, 200, 550));
      canvas.drawCircle(
        center,
        outer * (0.92 + 0.08 * grow),
        Paint()..color = primary,
      );
    }

    _paintRipples(canvas, center, outer, ms);
    _paintParticles(canvas, center, outer, ms);

    final draw = Motion.enter.transform(_span(ms, 350, 750));
    if (draw > 0) _paintCheck(canvas, center, side, draw);
  }

  void _paintRipples(Canvas canvas, Offset center, double radius, double ms) {
    for (var i = 0; i < 2; i++) {
      final start = 450 + i * _rippleGap;
      final t = _span(ms, start, start + 600);
      if (t <= 0 || t >= 1) continue;
      canvas.drawCircle(
        center,
        // The stroke stays inside [reach] so the outer ring never clips.
        radius * (1 + (reach - 1) * Motion.enter.transform(t)) - 1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = primary.withValues(alpha: _rippleOpacity * (1 - t)),
      );
    }
  }

  void _paintParticles(Canvas canvas, Offset center, double radius, double ms) {
    final t = _span(ms, 500, 1100);
    if (t <= 0 || t >= 1) return;
    final travel = Curves.easeOutCubic.transform(t);
    final fade = t < 0.5 ? 1.0 : 1 - (t - 0.5) * 2;
    final colors = [primary, container, onPrimary];
    final dot = radius * 0.05;

    for (var i = 0; i < _particles; i++) {
      // A fixed offset per particle keeps the burst from looking gridded.
      final angle = i * 2 * math.pi / _particles + (i.isEven ? 0.12 : -0.08);
      // Leaves room for the gravity drop and the dot itself inside [reach].
      final span = math.max(0.3, reach - 1.5);
      final spread = 0.75 + (i % 3) * 0.125;
      final distance = radius * (1.05 + span * spread * travel);
      final gravity = radius * 0.35 * t * t;
      final position =
          center +
          Offset(math.cos(angle), math.sin(angle)) * distance +
          Offset(0, gravity);
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: fade);

      if (i % 2 == 0) {
        canvas.drawCircle(position, dot, paint);
      } else {
        canvas
          ..save()
          ..translate(position.dx, position.dy)
          ..rotate(angle);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: dot * 3.2,
              height: dot * 1.2,
            ),
            Radius.circular(dot),
          ),
          paint,
        );
        canvas.restore();
      }
    }
  }

  void _paintCheck(Canvas canvas, Offset center, double side, double draw) {
    final s = side / 2;
    final path = Path()
      ..moveTo(center.dx - s * 0.38, center.dy + s * 0.02)
      ..lineTo(center.dx - s * 0.10, center.dy + s * 0.30)
      ..lineTo(center.dx + s * 0.40, center.dy - s * 0.26);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * _checkStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = onPrimary;

    final metrics = path.computeMetrics().toList();
    final length = metrics.fold<double>(0, (sum, m) => sum + m.length);
    var remaining = length * draw;
    for (final metric in metrics) {
      if (remaining <= 0) break;
      canvas.drawPath(
        metric.extractPath(0, math.min(remaining, metric.length)),
        paint,
      );
      remaining -= metric.length;
    }
  }

  @override
  bool shouldRepaint(SuccessBurstPainter old) =>
      old.animation != animation ||
      old.primary != primary ||
      old.container != container ||
      old.onPrimary != onPrimary ||
      old.reach != reach;
}
