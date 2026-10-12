import 'package:contextlens/core/theme/motion.dart';
import 'package:contextlens/features/splash/intro_controller.dart';
import 'package:contextlens/features/splash/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows the intro over the app, then fades through to it. Home builds
/// underneath while the intro plays, so it is ready when revealed.
///
/// The app subtree keeps the same widget types in every state so the
/// router's Navigator is never rebuilt when the intro hides or replays.
class SplashGate extends ConsumerStatefulWidget {
  const SplashGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends ConsumerState<SplashGate>
    with SingleTickerProviderStateMixin {
  // Fade through: the outgoing splash fades in the first 35%, then the app
  // fades in and settles from 92% scale.
  static const _outgoing = Interval(0, 0.35, curve: Motion.exit);
  static const _incoming = Interval(0.35, 1, curve: Motion.enter);
  static const _startScale = 0.92;

  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: Durations.medium2,
  );

  @override
  void dispose() {
    _exit.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_exit.isAnimating) return;
    await _exit.forward();
    if (mounted) ref.read(introControllerProvider.notifier).finish();
  }

  @override
  Widget build(BuildContext context) {
    final intro = ref.watch(introControllerProvider);
    final ready = ref.watch(appBootstrapProvider).hasValue;
    final reduced = MediaQuery.disableAnimationsOf(context);

    ref.listen(introControllerProvider, (previous, next) {
      if (next.visible && !(previous?.visible ?? false)) _exit.value = 0;
    });

    return Stack(
      children: [
        AnimatedBuilder(
          animation: _exit,
          child: widget.child,
          builder: (context, child) {
            final t = intro.visible
                ? (reduced ? _exit.value : _incoming.transform(_exit.value))
                : 1.0;
            return Opacity(
              opacity: t,
              child: Transform.scale(
                scale: reduced ? 1 : _startScale + (1 - _startScale) * t,
                child: child,
              ),
            );
          },
        ),
        if (intro.visible)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _exit,
              child: SplashPage(
                key: ValueKey(intro.hold),
                ready: ready,
                hold: intro.hold,
                onFinished: _finish,
              ),
              builder: (context, child) => Opacity(
                opacity:
                    1 -
                    (reduced ? _exit.value : _outgoing.transform(_exit.value)),
                child: child,
              ),
            ),
          ),
      ],
    );
  }
}
