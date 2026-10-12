import 'package:contextlens/core/theme/app_theme.dart';
import 'package:contextlens/core/theme/motion.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/widgets/lens_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Intro shown over Home on launch. Always dark so it continues the native
/// splash without a flash, whatever theme the user picked.
///
/// Timeline (1100 ms): ring draws 0 to 600, scan line settles 300 to 700,
/// badge pops 600 to 850, wordmark 600 to 900, then a short rest. If
/// [ready] is still false at the end it holds on the final frame with a
/// gentle pulse.
class SplashPage extends StatefulWidget {
  const SplashPage({
    required this.ready,
    required this.onFinished,
    this.hold = false,
    super.key,
  });

  final bool ready;
  final bool hold;
  final VoidCallback onFinished;

  /// Logo size. The native splash image is drawn at the same size and
  /// position so the handoff is seamless.
  static const double markSize = 96;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  static const _total = Duration(milliseconds: 1100);
  static const _reducedHold = Duration(milliseconds: 300);
  static const _pulsePeriod = Duration(milliseconds: 1200);
  static const _wordmarkRise = 12.0;
  static const _pulseMin = 0.55;

  late final AnimationController _intro = AnimationController(vsync: this);
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: _pulsePeriod,
  );

  late final Animation<double> _ring = _interval(0, 600, Motion.enter);
  late final Animation<double> _scan = _interval(300, 700, Motion.standard);
  late final Animation<double> _word = _interval(600, 900, Motion.enter);
  // The verified badge pops in once the ring has closed.
  late final Animation<double> _badge = _interval(600, 850, Curves.easeOutBack);

  bool _introDone = false;

  Animation<double> _interval(int startMs, int endMs, Curve curve) {
    final total = _total.inMilliseconds;
    return CurvedAnimation(
      parent: _intro,
      curve: Interval(startMs / total, endMs / total, curve: curve),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_intro.isAnimating || _introDone) return;
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced) {
      _intro.value = 1;
      Future<void>.delayed(_reducedHold, _onIntroDone);
    } else {
      _intro.duration = _total;
      _intro.forward().whenComplete(_onIntroDone);
    }
  }

  @override
  void didUpdateWidget(SplashPage old) {
    super.didUpdateWidget(old);
    _maybeFinish();
  }

  void _onIntroDone() {
    if (!mounted) return;
    _introDone = true;
    _maybeFinish();
  }

  void _maybeFinish() {
    if (!_introDone) return;
    if (widget.ready && !widget.hold) {
      _pulse.stop();
      widget.onFinished();
    } else if (!widget.hold &&
        !_pulse.isAnimating &&
        !MediaQuery.disableAnimationsOf(context)) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.dark;
    final scheme = theme.colorScheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status bar icons on the always-dark splash.
      value: SystemUiOverlayStyle.light,
      child: Theme(
        data: theme,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.hold ? widget.onFinished : null,
          child: Material(
            color: theme.scaffoldBackgroundColor,
            child: Semantics(
              label: 'ContextLens',
              container: true,
              excludeSemantics: true,
              child: AnimatedBuilder(
                animation: Listenable.merge([_intro, _pulse]),
                builder: (context, _) {
                  final pulse = 1 - _pulse.value * (1 - _pulseMin);
                  return SizedBox.expand(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        RepaintBoundary(
                          child: CustomPaint(
                            size: const Size.square(SplashPage.markSize),
                            painter: LensMarkPainter(
                              color: scheme.primary,
                              highlight: scheme.onPrimaryContainer,
                              ring: _ring.value,
                              scan: _scan.value,
                              glint: _word.value,
                              badge: _badge.value,
                              opacity: pulse,
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(
                            0,
                            SplashPage.markSize / 2 +
                                Spacing.space10 +
                                _wordmarkRise * (1 - _word.value),
                          ),
                          child: Opacity(
                            opacity: _word.value,
                            child: Text(
                              'ContextLens',
                              style: theme.textTheme.headlineSmall,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
