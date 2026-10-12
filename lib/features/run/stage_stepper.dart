import 'dart:math' as math;

import 'package:contextlens/core/theme/motion.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/features/report/models.dart';
import 'package:flutter/material.dart';

const _stages = [
  (JobStage.extract, 'Reading your video'),
  (JobStage.claims, 'Finding claims'),
  (JobStage.checking, 'Checking claims'),
  (JobStage.evidence, 'Weighing the evidence'),
  (JobStage.report, 'Writing your report'),
];

enum _DotState { pending, active, complete, failed }

/// Vertical stepper: the finished upload, then the five processing stages. The active stage pulses
/// and shows the backend's live detail; completed stages fill and draw a
/// check; the connecting line fills top to bottom.
class StageStepper extends StatelessWidget {
  const StageStepper({
    required this.job,
    this.firstDotKey,
    this.hideFirstDot = false,
    super.key,
  });

  static const double dotSize = 24;

  final Job job;

  /// Lets the success burst land exactly on the first dot.
  final GlobalKey? firstDotKey;

  /// Hidden while the success disc is flying into its place.
  final bool hideFirstDot;

  int get _activeIndex {
    final index = _stages.indexWhere((s) => s.$1 == job.stage);
    return index < 0 ? 0 : index;
  }

  _DotState _stateOf(int index) {
    if (job.status == JobStatus.done) return _DotState.complete;
    final active = _activeIndex;
    if (index < active) return _DotState.complete;
    if (index > active) return _DotState.pending;
    return job.status == JobStatus.failed ? _DotState.failed : _DotState.active;
  }

  @override
  Widget build(BuildContext context) {
    // The upload is the first, already finished step. The success disc lands
    // on its dot, so the check it carries is the one that stays.
    return Column(
      children: [
        _StageRow(
          label: 'Uploaded',
          detail: null,
          state: _DotState.complete,
          isLast: false,
          lineFilled: true,
          dotKey: firstDotKey,
          hideDot: hideFirstDot,
        ),
        for (var i = 0; i < _stages.length; i++)
          _StageRow(
            label: _stages[i].$2,
            detail: _stateOf(i) == _DotState.active ? job.stageDetail : null,
            state: _stateOf(i),
            isLast: i == _stages.length - 1,
            lineFilled: _stateOf(i) == _DotState.complete,
          ),
      ],
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.label,
    required this.detail,
    required this.state,
    required this.isLast,
    required this.lineFilled,
    this.dotKey,
    this.hideDot = false,
  });

  final String label;
  final String? detail;
  final _DotState state;
  final bool isLast;
  final bool lineFilled;
  final GlobalKey? dotKey;
  final bool hideDot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final motion = Motion.of(context);
    final text = detail;
    final isActive = state == _DotState.active;
    final labelColor = state == _DotState.pending
        ? scheme.onSurfaceVariant
        : scheme.onSurface;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: StageStepper.dotSize,
            child: Column(
              children: [
                Opacity(
                  opacity: hideDot ? 0 : 1,
                  child: _StageDot(key: dotKey, state: state),
                ),
                if (!isLast)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: Spacing.space1,
                      ),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: lineFilled ? 1 : 0),
                        duration: motion.medium2,
                        curve: Motion.standard,
                        builder: (context, fill, _) => CustomPaint(
                          painter: _LinePainter(
                            fill: fill,
                            track: scheme.outlineVariant,
                            color: scheme.primary,
                          ),
                          child: const SizedBox(width: 2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.space4),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : Spacing.space6),
              child: Semantics(
                liveRegion: isActive,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: labelColor,
                      ),
                    ),
                    if (text != null) ...[
                      const SizedBox(height: Spacing.space1),
                      Text(
                        text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageDot extends StatefulWidget {
  const _StageDot({required this.state, super.key});

  final _DotState state;

  @override
  State<_StageDot> createState() => _StageDotState();
}

class _StageDotState extends State<_StageDot> with TickerProviderStateMixin {
  static const _pulsePeriod = Duration(milliseconds: 1200);

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: _pulsePeriod,
  );
  late final AnimationController _check = AnimationController(
    vsync: this,
    duration: Durations.short4 + Durations.short2,
    value: widget.state == _DotState.complete ? 1 : 0,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(_StageDot old) {
    super.didUpdateWidget(old);
    _syncPulse();
    if (widget.state == _DotState.complete && old.state != _DotState.complete) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _check.value = 1;
      } else {
        _check.forward(from: 0);
      }
    }
  }

  void _syncPulse() {
    final shouldPulse =
        widget.state == _DotState.active &&
        !MediaQuery.disableAnimationsOf(context);
    if (shouldPulse && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!shouldPulse && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _check.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: StageStepper.dotSize,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _DotPainter(
            state: widget.state,
            pulse: _pulse,
            check: _check,
            primary: scheme.primary,
            onPrimary: scheme.onPrimary,
            error: scheme.error,
            onError: scheme.onError,
            outline: scheme.outline,
          ),
        ),
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  _DotPainter({
    required this.state,
    required this.pulse,
    required this.check,
    required this.primary,
    required this.onPrimary,
    required this.error,
    required this.onError,
    required this.outline,
  }) : super(repaint: Listenable.merge([pulse, check]));

  final _DotState state;
  final Animation<double> pulse;
  final Animation<double> check;
  final Color primary;
  final Color onPrimary;
  final Color error;
  final Color onError;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    switch (state) {
      case _DotState.pending:
        canvas.drawCircle(
          center,
          r - 1,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = outline,
        );
      case _DotState.active:
        final t = Motion.standard.transform(pulse.value);
        canvas
          ..drawCircle(
            center,
            r * (0.7 + 0.6 * t),
            Paint()..color = primary.withValues(alpha: 0.35 * (1 - t)),
          )
          ..drawCircle(
            center,
            r - 1,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = primary,
          )
          ..drawCircle(center, r * 0.38, Paint()..color = primary);
      case _DotState.complete:
        canvas.drawCircle(center, r, Paint()..color = primary);
        _paintCheck(canvas, center, r);
      case _DotState.failed:
        canvas.drawCircle(center, r, Paint()..color = error);
        final paint = Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = onError;
        final d = r * 0.35;
        canvas
          ..drawLine(center + Offset(-d, -d), center + Offset(d, d), paint)
          ..drawLine(center + Offset(d, -d), center + Offset(-d, d), paint);
    }
  }

  void _paintCheck(Canvas canvas, Offset center, double r) {
    final path = Path()
      ..moveTo(center.dx - r * 0.42, center.dy + r * 0.02)
      ..lineTo(center.dx - r * 0.12, center.dy + r * 0.32)
      ..lineTo(center.dx + r * 0.44, center.dy - r * 0.28);
    final progress = Motion.enter.transform(check.value);
    final metric = path.computeMetrics().first;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = onPrimary;
    // The path is a single contour, so one metric covers both strokes.
    canvas.drawPath(
      metric.extractPath(0, math.max(0, metric.length * progress)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_DotPainter old) =>
      old.state != state || old.primary != primary || old.outline != outline;
}

class _LinePainter extends CustomPainter {
  const _LinePainter({
    required this.fill,
    required this.track,
    required this.color,
  });

  final double fill;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final paint = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint..color = track);
    if (fill > 0) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height * fill),
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.fill != fill || old.track != track || old.color != color;
}
