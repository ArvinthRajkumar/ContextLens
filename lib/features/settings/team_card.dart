import 'dart:async';
import 'dart:math' as math;

import 'package:contextlens/core/theme/colors.dart';
import 'package:contextlens/core/theme/motion.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/widgets/glass_surface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Who built ContextLens. A glass card over a slowly drifting aurora; the
/// name "Tekken" rises in letter by letter, filled with a moving gradient
/// and crossed by a glossy sheen, and the members follow as glass pills.
/// Still when the system asks for less motion, paused off screen.
class TeamCard extends StatefulWidget {
  const TeamCard({super.key});

  static const members = ['Arvinth', 'Anju Priya Manam', 'Akash'];
  static const team = 'Tekken';

  @override
  State<TeamCard> createState() => _TeamCardState();
}

class _TeamCardState extends State<TeamCard> with TickerProviderStateMixin {
  /// Seconds since the aurora started, for the drift and the sheen.
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(
    (elapsed) => _time.value = _base + elapsed.inMicroseconds / 1e6,
  );
  double _base = 0;

  /// The entrance: letters, then members. Plays once.
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: _revealDuration,
  );

  static const _revealDuration = Duration(milliseconds: 1600);

  ScrollPosition? _scroll;
  bool _visible = true;

  bool get _still => MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scroll?.removeListener(_checkVisible);
    _scroll = Scrollable.maybeOf(context)?.position;
    _scroll?.addListener(_checkVisible);
    _sync();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkVisible();
    });
  }

  void _sync() {
    if (_still) {
      _reveal.value = 1;
      if (_ticker.isActive) _ticker.stop();
      return;
    }
    if (_visible && !_reveal.isCompleted && !_reveal.isAnimating) {
      unawaited(_reveal.forward());
    }
    if (_visible && !_ticker.isActive) {
      unawaited(_ticker.start());
    } else if (!_visible && _ticker.isActive) {
      _base = _time.value;
      _ticker.stop();
    }
  }

  /// Pauses the aurora while the card is scrolled out of the viewport.
  void _checkVisible() {
    final box = context.findRenderObject() as RenderBox?;
    final viewport = _scroll?.context.notificationContext?.findRenderObject();
    if (box == null || viewport is! RenderBox || !box.attached) return;
    final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
    final visible = top + box.size.height > 0 && top < viewport.size.height;
    if (visible != _visible) {
      _visible = visible;
      _sync();
    }
  }

  @override
  void dispose() {
    _scroll?.removeListener(_checkVisible);
    _ticker.dispose();
    _reveal.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: Radii.card,
        boxShadow: colors.cardShadows,
      ),
      child: ClipRRect(
        borderRadius: Radii.card,
        child: RepaintBoundary(
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _AuroraPainter(_time)),
              ),
              GlassSurface(
                faint: true,
                borderRadius: Radii.card,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.space5,
                    Spacing.space6,
                    Spacing.space5,
                    Spacing.space5,
                  ),
                  child: Column(
                    children: [
                      Semantics(
                        label: 'Team ${TeamCard.team}',
                        excludeSemantics: true,
                        child: _Name(reveal: _reveal, time: _time),
                      ),
                      const SizedBox(height: Spacing.space4),
                      _Members(reveal: _reveal),
                      const SizedBox(height: Spacing.space4),
                      Text(
                        'Built for Google Cloud AI Builder Cup 2026',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three pools of colored light drifting on slow Lissajous paths.
class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.time) : super(repaint: time);

  final ValueListenable<double> time;

  static const _colors = [
    TeamColors.auroraTeal,
    TeamColors.auroraSky,
    TeamColors.auroraViolet,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    for (final (i, color) in _colors.indexed) {
      // Each pool has its own pace and phase so they never line up.
      final speed = 0.13 + 0.05 * i;
      final phase = i * 2.1;
      final center = Offset(
        size.width * (0.5 + 0.38 * math.sin(t * speed + phase)),
        size.height * (0.5 + 0.42 * math.cos(t * speed * 1.3 + phase)),
      );
      final radius = size.width * (0.42 + 0.06 * math.sin(t * 0.21 + i));
      final tint = color.withValues(alpha: TeamColors.auroraAlpha);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(colors: [tint, tint.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => false;
}

/// "Tekken", letter by letter: each rises and settles with a little
/// overshoot. The fill is a gradient that slides slowly through the
/// letters, and every few seconds a glossy band sweeps across.
class _Name extends StatelessWidget {
  const _Name({required this.reveal, required this.time});

  final Animation<double> reveal;
  final ValueListenable<double> time;

  static const double _size = 52;
  static const double _rise = 18;

  /// The letters share the first 70% of the reveal, each starting a bit
  /// after the last.
  static const double _lettersEnd = 0.7;
  static const double _stagger = 0.08;

  /// Seconds between sheen passes, and how long one pass takes.
  static const double _sheenEvery = 4.5;
  static const double _sheenPass = 1.1;

  @override
  Widget build(BuildContext context) {
    final base = (Theme.of(context).textTheme.displaySmall ?? const TextStyle())
        .copyWith(
          fontSize: _size,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
          height: 1.1,
        );
    const letters = TeamCard.team;
    const span = _lettersEnd - _stagger * (letters.length - 1);

    final word = AnimatedBuilder(
      animation: reveal,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, letter) in letters.split('').indexed)
            Builder(
              builder: (context) {
                final start = _stagger * i;
                final raw = ((reveal.value - start) / span).clamp(0.0, 1.0);
                final rise = Motion.emphasized.transform(raw);
                return Opacity(
                  opacity: Curves.easeOut.transform(raw),
                  child: Transform.translate(
                    offset: Offset(0, _rise * (1 - rise)),
                    child: Transform.scale(
                      scale: 0.9 + 0.1 * Curves.easeOutBack.transform(raw),
                      child: Text(letter, style: base),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );

    return ValueListenableBuilder<double>(
      valueListenable: time,
      builder: (context, t, child) {
        final drift = (t * 0.08) % 1;
        final cycle = t % _sheenEvery;
        final sheen = cycle < _sheenPass ? cycle / _sheenPass : -1.0;
        return Stack(
          alignment: Alignment.center,
          children: [
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (rect) => LinearGradient(
                colors: TeamColors.name,
                transform: _Slide(drift),
                tileMode: TileMode.repeated,
              ).createShader(rect),
              child: child,
            ),
            if (sheen >= 0)
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment(-1 + 3 * sheen - 0.4, -1),
                  end: Alignment(-1 + 3 * sheen + 0.4, 1),
                  colors: [
                    TeamColors.sheen.withValues(alpha: 0),
                    TeamColors.sheen,
                    TeamColors.sheen.withValues(alpha: 0),
                  ],
                ).createShader(rect),
                child: child,
              ),
          ],
        );
      },
      child: word,
    );
  }
}

/// Moves a gradient sideways by [fraction] of the box.
class _Slide extends GradientTransform {
  const _Slide(this.fraction);

  final double fraction;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * fraction, 0, 0);
}

/// The members as small glass pills, fading up after the name.
class _Members extends StatelessWidget {
  const _Members({required this.reveal});

  final Animation<double> reveal;

  static const double _from = 0.55;
  static const double _rise = 10;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: Spacing.space2,
      runSpacing: Spacing.space2,
      children: [
        for (final (i, name) in TeamCard.members.indexed)
          AnimatedBuilder(
            animation: reveal,
            builder: (context, child) {
              final start = _from + 0.1 * i;
              final raw = ((reveal.value - start) / (1 - start)).clamp(
                0.0,
                1.0,
              );
              final t = Motion.standard.transform(raw);
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, _rise * (1 - t)),
                  child: child,
                ),
              );
            },
            child: GlassSurface(
              borderRadius: const BorderRadius.all(Radius.circular(Radii.full)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.space3,
                  vertical: Spacing.space2,
                ),
                child: Text(name, style: style),
              ),
            ),
          ),
      ],
    );
  }
}
