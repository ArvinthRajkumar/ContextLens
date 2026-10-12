import 'dart:math' as math;

import 'package:contextlens/core/theme/motion.dart';
import 'package:flutter/material.dart';

enum RingMode { running, paused, error }

/// Circular upload progress: 160dp, 10dp stroke, round caps. Progress
/// changes tween for 200 ms so chunk jumps read as continuous motion.
/// Paused dims the ring and dashes the track; an error shakes it once.
class UploadRing extends StatefulWidget {
  const UploadRing({
    required this.progress,
    this.mode = RingMode.running,
    this.child,
    super.key,
  });

  static const double size = 160;
  static const double stroke = 10;

  final double progress;
  final RingMode mode;
  final Widget? child;

  @override
  State<UploadRing> createState() => _UploadRingState();
}

class _UploadRingState extends State<UploadRing>
    with SingleTickerProviderStateMixin {
  static const _shakeDistance = 3.0;
  static const _shakeCycles = 2;

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: Durations.short4,
  );

  @override
  void didUpdateWidget(UploadRing old) {
    super.didUpdateWidget(old);
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (widget.mode == RingMode.error &&
        old.mode != RingMode.error &&
        !reduced) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = Motion.of(context);
    final color = switch (widget.mode) {
      RingMode.running => scheme.primary,
      RingMode.paused => scheme.onSurfaceVariant,
      RingMode.error => scheme.error,
    };

    return Semantics(
      label: 'Upload progress',
      value: '${(widget.progress * 100).round()} percent',
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) => Transform.translate(
          offset: Offset(
            math.sin(_shake.value * math.pi * 2 * _shakeCycles) *
                _shakeDistance,
            0,
          ),
          child: child,
        ),
        child: SizedBox.square(
          dimension: UploadRing.size,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: widget.progress.clamp(0, 1)),
            duration: motion.reduced ? Duration.zero : Durations.short4,
            curve: Motion.linear,
            builder: (context, value, child) => RepaintBoundary(
              child: CustomPaint(
                painter: _RingPainter(
                  progress: value,
                  color: color,
                  track: scheme.outlineVariant,
                  dashed: widget.mode == RingMode.paused,
                ),
                child: child,
              ),
            ),
            child: Center(child: widget.child),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.dashed,
  });

  final double progress;
  final Color color;
  final Color track;
  final bool dashed;

  static const _dashes = 48;
  static const _start = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = UploadRing.stroke;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.shortestSide - stroke) / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    paint.color = track;
    if (dashed) {
      // Half of each segment drawn, with butt caps so dashes stay crisp.
      const segment = 2 * math.pi / _dashes;
      paint.strokeCap = StrokeCap.butt;
      for (var i = 0; i < _dashes; i++) {
        canvas.drawArc(rect, _start + i * segment, segment / 2, false, paint);
      }
      paint.strokeCap = StrokeCap.round;
    } else {
      canvas.drawArc(rect, 0, 2 * math.pi, false, paint);
    }

    if (progress > 0) {
      paint.color = color;
      canvas.drawArc(rect, _start, 2 * math.pi * progress, false, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.track != track ||
      old.dashed != dashed;
}
