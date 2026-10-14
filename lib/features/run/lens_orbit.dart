import 'dart:async';
import 'dart:math' as math;

import 'package:contextlens/core/theme/motion.dart';
import 'package:contextlens/core/widgets/lens_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Where the orbit is in its life: running, finishing (the lens parks at
/// the top and the ring closes), or stopped on a failure.
enum OrbitPhase { running, done, failed }

/// The processing loader: the lens mark circling a thin track with a comet
/// trail, a ripple each time it passes the top, the current stage's icon in
/// the middle and a flash when a stage completes. One painter, repainted by
/// one controller; the icon is a widget so it can crossfade.
class LensOrbit extends StatefulWidget {
  const LensOrbit({
    required this.stage,
    required this.icon,
    required this.phase,
    this.lensKey,
    this.hideLens = false,
    super.key,
  });

  /// Diameter of the track and the lens size.
  static const double track = 200;
  static const double lens = 56;
  static const double side = track + lens;
  static const Duration lap = Duration(milliseconds: 2400);
  static const Duration flash = Duration(milliseconds: 250);
  static const Duration close = Duration(milliseconds: 400);

  /// Stage index; a higher value than before means a stage completed.
  final int stage;
  final IconData icon;
  final OrbitPhase phase;

  /// Marks the lens's starting place at the top of the track, where the
  /// upload's success disc lands.
  final GlobalKey? lensKey;

  /// Hidden while the success disc flies in.
  final bool hideLens;

  @override
  State<LensOrbit> createState() => _LensOrbitState();
}

class _LensOrbitState extends State<LensOrbit> with TickerProviderStateMixin {
  late final AnimationController _lap = AnimationController(
    vsync: this,
    duration: LensOrbit.lap,
  );
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: LensOrbit.flash,
  );
  late final AnimationController _close = AnimationController(
    vsync: this,
    duration: LensOrbit.close,
  );

  /// Where the lens was when the orbit stopped, for parking it at the top.
  double _parkFrom = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(LensOrbit old) {
    super.didUpdateWidget(old);
    if (widget.stage > old.stage && widget.phase == OrbitPhase.running) {
      unawaited(HapticFeedback.selectionClick());
      if (!_reduced) unawaited(_flash.forward(from: 0));
    }
    if (widget.phase != old.phase || widget.hideLens != old.hideLens) _sync();
  }

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  void _sync() {
    final reduced = _reduced;
    switch (widget.phase) {
      case OrbitPhase.running:
        if (widget.hideLens) {
          _lap.stop();
        } else if (reduced) {
          // Static lens at the top with a slow breathing opacity.
          _lap.duration = LensOrbit.lap * 2;
          unawaited(_lap.repeat(reverse: true));
        } else if (!_lap.isAnimating) {
          _lap.duration = LensOrbit.lap;
          unawaited(_lap.repeat());
        }
      case OrbitPhase.done:
        _parkFrom = reduced ? 0 : _lap.value;
        _lap.stop();
        unawaited(_close.forward(from: reduced ? 1 : 0));
      case OrbitPhase.failed:
        _lap.stop();
    }
  }

  @override
  void dispose() {
    _lap.dispose();
    _flash.dispose();
    _close.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = Motion.of(context);
    final isDark = scheme.brightness == Brightness.dark;

    return SizedBox.square(
      dimension: LensOrbit.side,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              size: const Size.square(LensOrbit.side),
              painter: LensOrbitPainter(
                lap: _lap,
                flash: _flash,
                close: _close,
                parkFrom: _parkFrom,
                phase: widget.phase,
                reduced: motion.reduced,
                hideLens: widget.hideLens,
                track: scheme.outlineVariant,
                accent: scheme.primary,
                error: scheme.error,
                highlight: isDark
                    ? scheme.onPrimaryContainer
                    : scheme.primary.withValues(alpha: 0.55),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: motion.medium2,
            child: Icon(
              widget.phase == OrbitPhase.failed
                  ? Icons.error_outline
                  : widget.icon,
              key: ValueKey((widget.icon, widget.phase)),
              size: LensOrbit.lens * 0.6,
              color: widget.phase == OrbitPhase.failed
                  ? scheme.error
                  : scheme.onSurfaceVariant,
            ),
          ),
          Positioned(
            top: 0,
            child: SizedBox.square(
              key: widget.lensKey,
              dimension: LensOrbit.lens,
            ),
          ),
        ],
      ),
    );
  }
}

class LensOrbitPainter extends CustomPainter {
  LensOrbitPainter({
    required this.lap,
    required this.flash,
    required this.close,
    required this.parkFrom,
    required this.phase,
    required this.reduced,
    required this.hideLens,
    required this.track,
    required this.accent,
    required this.error,
    required this.highlight,
  }) : super(repaint: Listenable.merge([lap, flash, close]));

  final Animation<double> lap;
  final Animation<double> flash;
  final Animation<double> close;
  final double parkFrom;
  final OrbitPhase phase;
  final bool reduced;
  final bool hideLens;
  final Color track;
  final Color accent;
  final Color error;
  final Color highlight;

  static const int trailSegments = 7;
  static const double trailSpan = 0.06; // of a lap per segment
  static const double tilt = 0.22; // radians at the steepest point
  static const double flashScale = 0.12;

  /// Lap position 0..1, 0 at the top, clockwise.
  double get _position {
    if (reduced) return 0;
    return switch (phase) {
      OrbitPhase.running => lap.value,
      // Finish the lap and park at the top while the ring closes.
      OrbitPhase.done =>
        parkFrom + (1 - parkFrom) * Motion.emphasized.transform(close.value),
      OrbitPhase.failed => lap.value,
    };
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const radius = LensOrbit.track / 2;
    final ringColor = phase == OrbitPhase.failed ? error : track;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ringColor,
    );

    if (phase == OrbitPhase.done) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * close.value,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = accent,
      );
    }

    final position = _position;
    final angle = -math.pi / 2 + 2 * math.pi * position;

    if (!reduced && phase == OrbitPhase.running && !hideLens) {
      _ripple(canvas, center, radius);
      _trail(canvas, center, radius, angle);
    }
    if (!hideLens) _lens(canvas, center, radius, angle);
  }

  /// A faint ring spreading from the middle just after the lens passes the
  /// top, gone by a third of the lap.
  void _ripple(Canvas canvas, Offset center, double radius) {
    final t = lap.value / 0.33;
    if (t >= 1) return;
    canvas.drawCircle(
      center,
      radius * 0.25 + radius * 0.6 * Curves.easeOut.transform(t),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = accent.withValues(alpha: 0.22 * (1 - t)),
    );
  }

  /// Short arcs behind the lens, each fainter and thinner than the last.
  void _trail(Canvas canvas, Offset center, double radius, double angle) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (var i = 0; i < trailSegments; i++) {
      final fade = 1 - i / trailSegments;
      final end = angle - 2 * math.pi * trailSpan * (i + 0.6);
      canvas.drawArc(
        rect,
        end - 2 * math.pi * trailSpan,
        2 * math.pi * trailSpan,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1 + 3 * fade
          ..color = accent.withValues(alpha: 0.5 * fade * fade),
      );
    }
  }

  void _lens(Canvas canvas, Offset center, double radius, double angle) {
    final at = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    final pop = flash.value == 0
        ? 0.0
        : math.sin(
            math.pi * Curves.easeOutBack.transform(flash.value).clamp(0, 1),
          );
    final scale = 1 + flashScale * pop;
    // Leans into the curve: zero at the top and bottom, most at the sides.
    final lean = reduced ? 0.0 : tilt * math.sin(angle + math.pi / 2) * -1;
    // Reduced motion breathes the opacity instead of moving.
    final opacity = reduced ? 0.55 + 0.45 * lap.value : 1.0;

    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..rotate(lean)
      ..scale(scale);
    final painter = LensMarkPainter(
      color: phase == OrbitPhase.failed ? error : accent,
      highlight: highlight,
      opacity: opacity,
    );
    canvas.translate(-LensOrbit.lens / 2, -LensOrbit.lens / 2);
    painter.paint(canvas, const Size.square(LensOrbit.lens));
    canvas.restore();
  }

  @override
  bool shouldRepaint(LensOrbitPainter old) =>
      old.phase != phase ||
      old.reduced != reduced ||
      old.hideLens != hideLens ||
      old.parkFrom != parkFrom ||
      old.track != track ||
      old.accent != accent ||
      old.error != error ||
      old.highlight != highlight;
}
