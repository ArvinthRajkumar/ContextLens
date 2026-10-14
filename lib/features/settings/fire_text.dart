import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:contextlens/core/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A word on fire: a fragment shader draws flames rising from the letters'
/// top edges, heat shimmer and a glowing orange to yellow inside, and a
/// small particle painter adds embers drifting up. Pauses when scrolled
/// out of view; with system animations off it shows the still glow.
class FireText extends StatefulWidget {
  const FireText({required this.text, required this.style, super.key});

  final String text;
  final TextStyle style;

  /// Room above the letters for the flames, as a share of the text height.
  static const double flameRoom = 0.9;

  @override
  State<FireText> createState() => _FireTextState();
}

class _FireTextState extends State<FireText>
    with SingleTickerProviderStateMixin {
  static ui.FragmentProgram? _program;

  late final Ticker _ticker = createTicker(_tick);
  final _time = ValueNotifier<double>(0);
  final _embers = _Embers();
  ui.FragmentShader? _shader;
  ui.Image? _mask;
  Size _maskSize = Size.zero;
  double _maskRatio = 1;
  ScrollPosition? _scroll;
  bool _visible = true;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      _program ??= await ui.FragmentProgram.fromAsset('shaders/fire_text.frag');
    } on Object {
      return; // No shader support: the plain gradient text stays.
    }
    if (!mounted) return;
    setState(() => _shader = _program!.fragmentShader());
  }

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

  bool get _still => MediaQuery.disableAnimationsOf(context);

  void _sync() {
    final run = _visible && !_still;
    if (run && !_ticker.isActive) {
      _last = Duration.zero;
      unawaited(_ticker.start());
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  /// Stops the fire while the card is scrolled out of the viewport.
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

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _embers.step(dt.clamp(0, 0.05));
    _time.value = elapsed.inMicroseconds / 1e6;
  }

  /// Renders the word white on transparent at the device pixel ratio, for
  /// the shader to sample.
  void _ensureMask(Size size, TextPainter painter, double dpr) {
    if (_mask != null && _maskSize == size && _maskRatio == dpr) return;
    _maskSize = size;
    _maskRatio = dpr;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(dpr);
    painter.paint(
      canvas,
      Offset((size.width - painter.width) / 2, size.height - painter.height),
    );
    final image = recorder.endRecording().toImageSync(
      (size.width * dpr).ceil(),
      (size.height * dpr).ceil(),
    );
    _mask?.dispose();
    _mask = image;
  }

  @override
  void dispose() {
    _scroll?.removeListener(_checkVisible);
    _ticker.dispose();
    _time.dispose();
    _mask?.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final white = TextPainter(
      text: TextSpan(
        text: widget.text,
        style: widget.style.copyWith(color: FireColors.mask),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final size = Size(
      white.width * 1.12,
      white.height * (1 + FireText.flameRoom),
    );
    final shader = _shader;
    if (shader != null) _ensureMask(size, white, dpr);

    return Semantics(
      label: widget.text,
      excludeSemantics: true,
      child: RepaintBoundary(
        child: CustomPaint(
          size: size,
          painter: _FirePainter(
            time: _time,
            shader: shader,
            mask: _mask,
            embers: _embers,
            text: white,
            still: _still,
          ),
        ),
      ),
    );
  }
}

class _FirePainter extends CustomPainter {
  _FirePainter({
    required this.time,
    required this.shader,
    required this.mask,
    required this.embers,
    required this.text,
    required this.still,
  }) : super(repaint: time);

  final ValueNotifier<double> time;
  final ui.FragmentShader? shader;
  final ui.Image? mask;
  final _Embers embers;
  final TextPainter text;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final textTop = size.height - text.height;
    final shader = this.shader;
    final mask = this.mask;
    if (shader != null && mask != null) {
      shader
        ..setFloat(0, size.width)
        ..setFloat(1, size.height)
        // A frozen moment of the fire when animations are off.
        ..setFloat(2, still ? 1.7 : time.value)
        ..setImageSampler(0, mask);
      canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
    } else {
      // Fallback: the same warm gradient without the flames.
      final fill = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [FireColors.glowTop, FireColors.glowBottom],
        ).createShader(Rect.fromLTWH(0, textTop, size.width, text.height));
      canvas.saveLayer(Offset.zero & size, Paint());
      text.paint(canvas, Offset((size.width - text.width) / 2, textTop));
      canvas
        ..drawRect(Offset.zero & size, fill..blendMode = BlendMode.srcIn)
        ..restore();
    }
    if (still) return;
    embers.paint(
      canvas,
      Rect.fromLTWH(
        (size.width - text.width) / 2,
        textTop,
        text.width,
        text.height,
      ),
      FireColors.ember,
    );
  }

  @override
  bool shouldRepaint(_FirePainter old) =>
      old.shader != shader || old.mask != mask || old.still != still;
}

/// Small sparks that leave the letters' tops, drift and fade.
class _Embers {
  _Embers() {
    for (var i = 0; i < _count; i++) {
      _spawn(_Ember(), age: _random.nextDouble() * _life);
    }
  }

  static const int _count = 22;
  static const double _life = 2.2;
  final _random = math.Random(7);
  final List<_Ember> _all = List.generate(_count, (_) => _Ember());

  void _spawn(_Ember e, {double age = 0}) {
    e
      ..x = _random.nextDouble()
      ..y = 0.1 + _random.nextDouble() * 0.15
      ..vx = (_random.nextDouble() - 0.5) * 0.06
      ..vy = 0.35 + _random.nextDouble() * 0.45
      ..phase = _random.nextDouble() * math.pi * 2
      ..size = 0.9 + _random.nextDouble() * 1.6
      ..age = age;
  }

  void step(double dt) {
    for (final e in _all) {
      e.age += dt;
      if (e.age >= _life) {
        _spawn(e);
        continue;
      }
      e
        ..x += e.vx * dt
        ..y += e.vy * dt;
    }
  }

  /// [letters] is the box of the word; embers rise from its top edge.
  void paint(Canvas canvas, Rect letters, Color color) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
    for (final e in _all) {
      final life = (e.age / _life).clamp(0.0, 1.0);
      final fade = life < 0.15 ? life / 0.15 : 1 - (life - 0.15) / 0.85;
      final sway = math.sin(e.phase + e.age * 3) * 6;
      final dx = letters.left + e.x * letters.width + sway;
      final dy = letters.top + letters.height * 0.15 - e.y * letters.height;
      paint.color = color.withValues(alpha: 0.9 * fade);
      canvas.drawCircle(Offset(dx, dy), e.size, paint);
    }
  }
}

class _Ember {
  double x = 0;
  double y = 0;
  double vx = 0;
  double vy = 0;
  double phase = 0;
  double size = 1;
  double age = 0;
}
