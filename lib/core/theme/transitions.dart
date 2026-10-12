import 'package:animations/animations.dart';
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
    if (MediaQuery.disableAnimationsOf(context)) {
      return FadeTransition(opacity: animation, child: child);
    }
    return _sharedAxis.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
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
    child: child,
    transitionDuration: Durations.medium2,
    reverseTransitionDuration: Durations.medium2,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) {
        return FadeTransition(opacity: animation, child: child);
      }
      return FadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        fillColor: Theme.of(context).scaffoldBackgroundColor,
        child: child,
      );
    },
  );
}
