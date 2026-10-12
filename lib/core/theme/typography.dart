import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const String sans = 'Inter';
  static const String mono = 'JetBrainsMono';

  static TextTheme textTheme(Color onSurface) {
    TextStyle style(
      double size,
      double lineHeight,
      FontWeight weight, [
      double letterSpacing = 0,
    ]) {
      return TextStyle(
        fontFamily: sans,
        fontSize: size,
        height: lineHeight / size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        color: onSurface,
      );
    }

    return TextTheme(
      displaySmall: style(36, 44, FontWeight.w600, -0.5),
      headlineSmall: style(24, 32, FontWeight.w600),
      titleLarge: style(20, 28, FontWeight.w600),
      titleMedium: style(16, 24, FontWeight.w600),
      titleSmall: style(14, 20, FontWeight.w600),
      bodyLarge: style(16, 24, FontWeight.w400),
      bodyMedium: style(14, 20, FontWeight.w400),
      bodySmall: style(12, 16, FontWeight.w400),
      labelLarge: style(14, 20, FontWeight.w600, 0.1),
      labelMedium: style(12, 16, FontWeight.w600, 0.5),
      labelSmall: style(11, 16, FontWeight.w600, 0.5),
    );
  }

  /// Tabular monospace for timecodes, speed, ETA and counts, so digits
  /// don't shift while values tick.
  static TextStyle monoOf(TextStyle? base) {
    return (base ?? const TextStyle()).copyWith(
      fontFamily: mono,
      fontFeatures: const [FontFeature.tabularFigures()],
      letterSpacing: 0,
    );
  }
}
