import 'package:flutter/material.dart';

/// Material 3 motion tokens. Enter uses decelerate, exit uses accelerate,
/// and exit is shorter than enter.
///
/// Read through [Motion.of] so reduced motion (the system setting or the
/// in-app override, both surfaced as [MediaQueryData.disableAnimations])
/// collapses every duration to zero.
@immutable
class Motion {
  const Motion._({required this.reduced});

  static const Motion full = Motion._(reduced: false);
  static const Motion reducedMotion = Motion._(reduced: true);

  final bool reduced;

  static Motion of(BuildContext context) {
    return MediaQuery.disableAnimationsOf(context) ? reducedMotion : full;
  }

  Duration _d(Duration value) => reduced ? Duration.zero : value;

  Duration get short2 => _d(Durations.short2);
  Duration get short4 => _d(Durations.short4);
  Duration get medium2 => _d(Durations.medium2);
  Duration get medium4 => _d(Durations.medium4);
  Duration get long2 => _d(Durations.long2);
  Duration get extraLong1 => _d(Durations.extralong1);

  static const Curve standard = Easing.standard;
  static const Curve enter = Easing.emphasizedDecelerate;
  static const Curve exit = Easing.emphasizedAccelerate;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  /// Only for progress values and opacity.
  static const Curve linear = Curves.linear;
}
