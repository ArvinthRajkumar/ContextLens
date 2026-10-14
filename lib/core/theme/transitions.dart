import 'package:animations/animations.dart';
import 'package:contextlens/core/widgets/app_background.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shared axis (horizontal) for the forward flow, a plain fade when
/// reduced motion is on.
class MotionAwarePageTransitionsBuilder extends PageTransitionsBuilder {
  const MotionAwarePageTransitionsBuilder();

  static const _sharedAxis = SharedAxisPageTransitionsBuilder(
    transitionType: SharedAxisTransitionType.horizontal,
  );

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final page = AppBackground(child: child);
    if (MediaQuery.disableAnimationsOf(context)) {
      return FadeTransition(opacity: animation, child: page);
    }
    return _sharedAxis.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      page,
    );
  }
}

/// Fade through, for moves between unrelated screens (Home and Settings,
/// Run to Report).
CustomTransitionPage<void> fadeThroughPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: AppBackground(child: child),
    transitionDuration: Durations.medium2,
    reverseTransitionDuration: Durations.medium2,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) {
        return FadeTransition(opacity: animation, child: child);
      }
      return FadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        fillColor: Theme.of(context).colorScheme.surface,
        child: child,
      );
    },
  );
}
