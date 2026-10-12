import 'package:flutter/material.dart';

/// Raw color tokens for one brightness. Widgets read colors through
/// [ColorScheme] and [AppColors], never from here directly.
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.outline,
    required this.outlineVariant,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.error,
    required this.onError,
    required this.disclosure,
    required this.claims,
    required this.visuals,
    required this.borrowed,
    required this.factcheck,
    required this.supported,
    required this.contradicted,
    required this.previouslyFactChecked,
    required this.insufficientEvidence,
  });

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color outline;
  final Color outlineVariant;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color error;
  final Color onError;
  final Color disclosure;
  final Color claims;
  final Color visuals;
  final Color borrowed;
  final Color factcheck;
  final Color supported;
  final Color contradicted;
  final Color previouslyFactChecked;
  final Color insufficientEvidence;

  static const dark = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF0B0F14),
    surface: Color(0xFF11161D),
    surfaceContainer: Color(0xFF161C24),
    surfaceContainerHigh: Color(0xFF1C232D),
    outline: Color(0xFF2A3340),
    outlineVariant: Color(0xFF1F2731),
    onSurface: Color(0xFFE6EBF1),
    onSurfaceVariant: Color(0xFF9AA6B2),
    primary: Color(0xFF3DD6C6),
    onPrimary: Color(0xFF00201D),
    primaryContainer: Color(0xFF0E3B37),
    onPrimaryContainer: Color(0xFF9CF2E8),
    error: Color(0xFFFF6B6B),
    onError: Color(0xFF3B0A0A),
    disclosure: Color(0xFFFFB547),
    claims: Color(0xFFFF7A90),
    visuals: Color(0xFF8AB4FF),
    borrowed: Color(0xFFC59BFF),
    factcheck: Color(0xFF3DD6C6),
    supported: Color(0xFF4ADE80),
    contradicted: Color(0xFFFF6B6B),
    previouslyFactChecked: Color(0xFF8AB4FF),
    insufficientEvidence: Color(0xFF9AA6B2),
  );

  // Where the spec's light values fell under 4.5:1 on white (primary,
  // disclosure, factcheck and the dark-only fact label colors), they are
  // darkened to the nearest passing shade. See test/contrast_test.dart.
  static const light = AppPalette(
    brightness: Brightness.light,
    background: Color(0xFFF7F9FB),
    surface: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFF0F3F6),
    surfaceContainerHigh: Color(0xFFE8ECF0),
    outline: Color(0xFFC5CDD6),
    outlineVariant: Color(0xFFDDE3E9),
    onSurface: Color(0xFF0E141B),
    onSurfaceVariant: Color(0xFF4A5663),
    primary: Color(0xFF00695C),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFC8F3EE),
    onPrimaryContainer: Color(0xFF00201D),
    error: Color(0xFFC62828),
    onError: Color(0xFFFFFFFF),
    disclosure: Color(0xFF9A5B00),
    claims: Color(0xFFC2185B),
    visuals: Color(0xFF1E5BD8),
    borrowed: Color(0xFF6B3FC4),
    factcheck: Color(0xFF00695C),
    supported: Color(0xFF166534),
    contradicted: Color(0xFFC62828),
    previouslyFactChecked: Color(0xFF1E5BD8),
    insufficientEvidence: Color(0xFF4A5663),
  );
}

/// Semantic colors that [ColorScheme] has no slot for.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.disclosure,
    required this.claims,
    required this.visuals,
    required this.borrowed,
    required this.factcheck,
    required this.supported,
    required this.contradicted,
    required this.previouslyFactChecked,
    required this.insufficientEvidence,
    required this.cardShadows,
    required this.cardBorder,
  });

  factory AppColors.fromPalette(AppPalette p) {
    final isDark = p.brightness == Brightness.dark;
    return AppColors(
      background: p.background,
      disclosure: p.disclosure,
      claims: p.claims,
      visuals: p.visuals,
      borrowed: p.borrowed,
      factcheck: p.factcheck,
      supported: p.supported,
      contradicted: p.contradicted,
      previouslyFactChecked: p.previouslyFactChecked,
      insufficientEvidence: p.insufficientEvidence,
      // Dark mode separates surfaces with tone and a hairline, light mode
      // with a soft shadow.
      cardShadows: isDark
          ? const []
          : const [
              BoxShadow(
                color: Color(0x0F000000),
                offset: Offset(0, 1),
                blurRadius: 2,
              ),
            ],
      cardBorder: isDark ? p.outlineVariant : null,
    );
  }

  final Color background;
  final Color disclosure;
  final Color claims;
  final Color visuals;
  final Color borrowed;
  final Color factcheck;
  final Color supported;
  final Color contradicted;
  final Color previouslyFactChecked;
  final Color insufficientEvidence;
  final List<BoxShadow> cardShadows;
  final Color? cardBorder;

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith({
    Color? background,
    Color? disclosure,
    Color? claims,
    Color? visuals,
    Color? borrowed,
    Color? factcheck,
    Color? supported,
    Color? contradicted,
    Color? previouslyFactChecked,
    Color? insufficientEvidence,
    List<BoxShadow>? cardShadows,
    Color? cardBorder,
  }) {
    return AppColors(
      background: background ?? this.background,
      disclosure: disclosure ?? this.disclosure,
      claims: claims ?? this.claims,
      visuals: visuals ?? this.visuals,
      borrowed: borrowed ?? this.borrowed,
      factcheck: factcheck ?? this.factcheck,
      supported: supported ?? this.supported,
      contradicted: contradicted ?? this.contradicted,
      previouslyFactChecked:
          previouslyFactChecked ?? this.previouslyFactChecked,
      insufficientEvidence: insufficientEvidence ?? this.insufficientEvidence,
      cardShadows: cardShadows ?? this.cardShadows,
      cardBorder: cardBorder ?? this.cardBorder,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      disclosure: Color.lerp(disclosure, other.disclosure, t)!,
      claims: Color.lerp(claims, other.claims, t)!,
      visuals: Color.lerp(visuals, other.visuals, t)!,
      borrowed: Color.lerp(borrowed, other.borrowed, t)!,
      factcheck: Color.lerp(factcheck, other.factcheck, t)!,
      supported: Color.lerp(supported, other.supported, t)!,
      contradicted: Color.lerp(contradicted, other.contradicted, t)!,
      previouslyFactChecked: Color.lerp(
        previouslyFactChecked,
        other.previouslyFactChecked,
        t,
      )!,
      insufficientEvidence: Color.lerp(
        insufficientEvidence,
        other.insufficientEvidence,
        t,
      )!,
      cardShadows: BoxShadow.lerpList(cardShadows, other.cardShadows, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t),
    );
  }
}
