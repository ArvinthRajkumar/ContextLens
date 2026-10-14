import 'package:flutter/material.dart';

/// Raw color tokens. Widgets read colors through [ColorScheme] and
/// [AppColors], never from here directly.
class AppPalette {
  const AppPalette({
    required this.skyTop,
    required this.skyMid,
    required this.skyBottom,
    required this.glass,
    required this.glassStrong,
    required this.glassFaint,
    required this.glassBorder,
    required this.glassShadow,
    required this.ink,
    required this.onInk,
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
    required this.seekPlayed,
    required this.seekBuffered,
    required this.seekTrack,
  });

  /// The page background runs from a pale sky at the top to white.
  final Color skyTop;
  final Color skyMid;
  final Color skyBottom;

  /// Liquid glass: translucent white over the sky, a white hairline and a
  /// soft cool shadow. [glassStrong] is for sheets and dialogs.
  final Color glass;
  final Color glassStrong;

  /// A step back from [glass], for uncertain flags.
  final Color glassFaint;
  final Color glassBorder;
  final Color glassShadow;

  /// Primary buttons: black with white text.
  final Color ink;
  final Color onInk;

  final Color outline;
  final Color outlineVariant;
  final Color onSurface;
  final Color onSurfaceVariant;

  /// Teal, the one accent.
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

  /// The video seek bar: played (video-player red), buffered, the rest.
  final Color seekPlayed;
  final Color seekBuffered;
  final Color seekTrack;

  /// Glass over the darkest part of the sky, the worst case for contrast.
  Color get glassOnSky => Color.alphaBlend(glass, skyTop);

  // Every text color passes 4.5:1 on the sky top, the glass over it and
  // white. See test/contrast_test.dart.
  static const light = AppPalette(
    skyTop: Color(0xFFCFE4F5),
    skyMid: Color(0xFFE6F1FA),
    skyBottom: Color(0xFFFAFCFE),
    glass: Color(0x9EFFFFFF),
    glassStrong: Color(0xEBFFFFFF),
    glassFaint: Color(0x59FFFFFF),
    glassBorder: Color(0xCCFFFFFF),
    glassShadow: Color(0x1A2B4A6B),
    ink: Color(0xFF0B0F14),
    onInk: Color(0xFFFFFFFF),
    outline: Color(0xFFB9C6D3),
    outlineVariant: Color(0x80B9C6D3),
    onSurface: Color(0xFF0B0F14),
    onSurfaceVariant: Color(0xFF45525F),
    primary: Color(0xFF00695E),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFCCF1EC),
    onPrimaryContainer: Color(0xFF00201D),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    disclosure: Color(0xFF8A5100),
    claims: Color(0xFFB0164F),
    visuals: Color(0xFF1D55C4),
    borrowed: Color(0xFF6236B8),
    factcheck: Color(0xFF00695E),
    supported: Color(0xFF15642F),
    contradicted: Color(0xFFB3261E),
    previouslyFactChecked: Color(0xFF1D55C4),
    insufficientEvidence: Color(0xFF45525F),
    seekPlayed: Color(0xFFFF0033),
    seekBuffered: Color(0x4D0B0F14),
    seekTrack: Color(0x1F0B0F14),
  );
}

/// Semantic colors that [ColorScheme] has no slot for.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.glass,
    required this.glassStrong,
    required this.glassFaint,
    required this.glassBorder,
    required this.ink,
    required this.onInk,
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
    required this.seekPlayed,
    required this.seekBuffered,
    required this.seekTrack,
  });

  factory AppColors.fromPalette(AppPalette p) {
    return AppColors(
      background: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [p.skyTop, p.skyMid, p.skyBottom],
        stops: const [0, 0.45, 1],
      ),
      glass: p.glass,
      glassStrong: p.glassStrong,
      glassFaint: p.glassFaint,
      glassBorder: p.glassBorder,
      ink: p.ink,
      onInk: p.onInk,
      disclosure: p.disclosure,
      claims: p.claims,
      visuals: p.visuals,
      borrowed: p.borrowed,
      factcheck: p.factcheck,
      supported: p.supported,
      contradicted: p.contradicted,
      previouslyFactChecked: p.previouslyFactChecked,
      insufficientEvidence: p.insufficientEvidence,
      cardShadows: [
        BoxShadow(
          color: p.glassShadow,
          offset: const Offset(0, 8),
          blurRadius: 24,
        ),
      ],
      seekPlayed: p.seekPlayed,
      seekBuffered: p.seekBuffered,
      seekTrack: p.seekTrack,
    );
  }

  /// The page background, behind every route.
  final Gradient background;
  final Color glass;
  final Color glassStrong;
  final Color glassFaint;
  final Color glassBorder;
  final Color ink;
  final Color onInk;
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
  final Color seekPlayed;
  final Color seekBuffered;
  final Color seekTrack;

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  // One theme, so copyWith and lerp only need to be well formed.
  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

/// The fire on the team name in About. Fixed colors: fire looks the same in
/// every theme, on its own dark card.
abstract final class FireColors {
  static const glowTop = Color(0xFFFFD54F);
  static const glowBottom = Color(0xFFFF6D00);
  static const ember = Color(0xFFFFB74D);

  /// The word as the shader samples it: white, alpha is what counts.
  static const mask = Color(0xFFFFFFFF);

  /// The dark glass card the fire sits on.
  static const card = Color(0xE6120C0A);
  static const cardBorder = Color(0x33FFB74D);
  static const onCard = Color(0xFFF5EDE6);
  static const onCardMuted = Color(0xB3F5EDE6);
}
