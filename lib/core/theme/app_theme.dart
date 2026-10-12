import 'package:contextlens/core/theme/colors.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/theme/transitions.dart';
import 'package:contextlens/core/theme/typography.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static final ThemeData dark = _build(AppPalette.dark);
  static final ThemeData light = _build(AppPalette.light);

  // Built by hand rather than from a seed: generated tonal palettes drift
  // toward the accent and wash out the semantic flag colors.
  static ColorScheme colorScheme(AppPalette p) {
    return ColorScheme(
      brightness: p.brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      primaryContainer: p.primaryContainer,
      onPrimaryContainer: p.onPrimaryContainer,
      secondary: p.primary,
      onSecondary: p.onPrimary,
      secondaryContainer: p.surfaceContainerHigh,
      onSecondaryContainer: p.onSurface,
      tertiary: p.visuals,
      onTertiary: p.onPrimary,
      error: p.error,
      onError: p.onError,
      surface: p.surface,
      onSurface: p.onSurface,
      onSurfaceVariant: p.onSurfaceVariant,
      surfaceContainerLowest: p.background,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surfaceContainer,
      surfaceContainerHigh: p.surfaceContainerHigh,
      surfaceContainerHighest: p.surfaceContainerHigh,
      outline: p.outline,
      outlineVariant: p.outlineVariant,
      scrim: const Color(0x99000000),
      shadow: const Color(0xFF000000),
      inverseSurface: p.onSurface,
      onInverseSurface: p.surface,
      inversePrimary: p.primaryContainer,
      surfaceTint: Colors.transparent,
    );
  }

  static ThemeData _build(AppPalette p) {
    final scheme = colorScheme(p);
    final text = AppTypography.textTheme(p.onSurface);
    const stadium = StadiumBorder();
    const buttonSize = Size(64, Spacing.minTouchTarget);
    const buttonPadding = EdgeInsets.symmetric(horizontal: Spacing.space6);

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      fontFamily: AppTypography.sans,
      textTheme: text,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      extensions: [AppColors.fromPalette(p)],
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: MotionAwarePageTransitionsBuilder(),
          TargetPlatform.iOS: MotionAwarePageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: stadium,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: stadium,
          textStyle: text.labelLarge,
          foregroundColor: p.onSurface,
          side: BorderSide(color: p.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: buttonSize,
          shape: stadium,
          textStyle: text.labelLarge,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.card,
          side: p.brightness == Brightness.dark
              ? BorderSide(color: p.outlineVariant)
              : BorderSide.none,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const RoundedRectangleBorder(borderRadius: Radii.chip),
        side: BorderSide(color: p.outline),
        labelStyle: text.labelLarge,
        backgroundColor: p.surfaceContainer,
        selectedColor: p.primaryContainer,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: buttonSize,
          textStyle: text.labelLarge,
          selectedBackgroundColor: p.primaryContainer,
          selectedForegroundColor: p.onPrimaryContainer,
          side: BorderSide(color: p.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.space4,
          vertical: Spacing.space3,
        ),
        border: OutlineInputBorder(
          borderRadius: Radii.chip,
          borderSide: BorderSide(color: p.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.chip,
          borderSide: BorderSide(color: p.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.chip,
          borderSide: BorderSide(color: p.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Radii.chip,
          borderSide: BorderSide(color: p.error),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Radii.sheet),
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(Radii.xl)),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.outlineVariant, thickness: 1),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: Spacing.space3,
        contentPadding: Spacing.screenPadding,
        iconColor: p.onSurfaceVariant,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodyMedium?.copyWith(color: p.onSurfaceVariant),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.outlineVariant,
        circularTrackColor: p.outlineVariant,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.onSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: p.surface),
        shape: const RoundedRectangleBorder(borderRadius: Radii.chip),
      ),
    );
  }
}
