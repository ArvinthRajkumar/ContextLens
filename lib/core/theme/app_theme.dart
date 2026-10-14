import 'package:contextlens/core/theme/colors.dart';
import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/theme/transitions.dart';
import 'package:contextlens/core/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppTheme {
  static final ThemeData light = _build(AppPalette.light);

  // Built by hand rather than from a seed: generated tonal palettes drift
  // toward the accent and wash out the semantic flag colors.
  static ColorScheme colorScheme(AppPalette p) {
    return ColorScheme(
      brightness: Brightness.light,
      primary: p.primary,
      onPrimary: p.onPrimary,
      primaryContainer: p.primaryContainer,
      onPrimaryContainer: p.onPrimaryContainer,
      secondary: p.primary,
      onSecondary: p.onPrimary,
      secondaryContainer: p.glassStrong,
      onSecondaryContainer: p.onSurface,
      tertiary: p.visuals,
      onTertiary: p.onPrimary,
      error: p.error,
      onError: p.onError,
      surface: p.skyBottom,
      onSurface: p.onSurface,
      onSurfaceVariant: p.onSurfaceVariant,
      surfaceContainerLowest: p.skyBottom,
      surfaceContainerLow: p.glass,
      surfaceContainer: p.glass,
      surfaceContainerHigh: p.glassStrong,
      surfaceContainerHighest: p.glassStrong,
      outline: p.outline,
      outlineVariant: p.outlineVariant,
      scrim: const Color(0x99000000),
      shadow: const Color(0xFF000000),
      inverseSurface: p.ink,
      onInverseSurface: p.onInk,
      inversePrimary: p.primaryContainer,
      surfaceTint: Colors.transparent,
    );
  }

  static ThemeData _build(AppPalette p) {
    final scheme = colorScheme(p);
    final text = AppTypography.textTheme(p.onSurface);
    const stadium = StadiumBorder();
    const buttonSize = Size(64, Spacing.buttonHeight);
    const buttonPadding = EdgeInsets.symmetric(horizontal: Spacing.space6);
    final glassSide = BorderSide(color: p.glassBorder);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      fontFamily: AppTypography.sans,
      textTheme: text,
      // Transparent so the sky gradient behind each route shows through.
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: p.skyBottom,
      extensions: [AppColors.fromPalette(p)],
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: MotionAwarePageTransitionsBuilder(),
          TargetPlatform.iOS: MotionAwarePageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: p.onSurface,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.ink,
          foregroundColor: p.onInk,
          disabledBackgroundColor: p.outlineVariant,
          disabledForegroundColor: p.onSurfaceVariant,
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
          backgroundColor: p.glassStrong,
          side: glassSide,
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.onSurface,
          minimumSize: buttonSize,
          shape: stadium,
          textStyle: text.labelLarge,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.glass,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.card,
          side: glassSide,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const RoundedRectangleBorder(borderRadius: Radii.chip),
        side: glassSide,
        labelStyle: text.labelLarge,
        backgroundColor: p.glassStrong,
        selectedColor: p.primaryContainer,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: buttonSize,
          textStyle: text.labelLarge,
          backgroundColor: p.glass,
          foregroundColor: p.onSurface,
          selectedBackgroundColor: p.ink,
          selectedForegroundColor: p.onInk,
          side: glassSide,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.glassStrong,
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
          borderSide: glassSide,
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
        // Opaque: text behind a translucent sheet reads as noise.
        backgroundColor: p.skyBottom,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Radii.sheet),
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.skyBottom,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(Radii.xl)),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.outlineVariant, thickness: 1),
      popupMenuTheme: PopupMenuThemeData(
        color: p.skyBottom,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Radii.chip),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? p.primary : p.glassStrong,
        ),
        trackOutlineColor: WidgetStatePropertyAll(p.outline),
      ),
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
        backgroundColor: p.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: p.onInk),
        shape: const RoundedRectangleBorder(borderRadius: Radii.chip),
      ),
    );
  }
}
