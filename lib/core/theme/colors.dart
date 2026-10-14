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
    required this.glassSheen,
    required this.glassEdgeFade,
    required this.blobTeal,
    required this.blobSky,
    required this.blobViolet,
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

  /// The lit corner of a glass card (top left) and where its edge fades
  /// (bottom right).
  final Color glassSheen;
  final Color glassEdgeFade;

  /// Soft light behind the glass, so its translucency reads.
  final Color blobTeal;
  final Color blobSky;
  final Color blobViolet;

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

  // Every text color passes 4.5:1 on the sky top, the glass over it, the
  // background light pools and white (about 6:1 on plain sky). See
  // test/contrast_test.dart.
  static const light = AppPalette(
    skyTop: Color(0xFFCFE4F5),
    skyMid: Color(0xFFE6F1FA),
    skyBottom: Color(0xFFFAFCFE),
    glass: Color(0x9EFFFFFF),
    glassStrong: Color(0xEBFFFFFF),
    glassFaint: Color(0x59FFFFFF),
    glassBorder: Color(0xCCFFFFFF),
    glassShadow: Color(0x1A2B4A6B),
    glassSheen: Color(0xE6FFFFFF),
    glassEdgeFade: Color(0x33FFFFFF),
    blobTeal: Color(0x5C2EC4B6),
    blobSky: Color(0x4D5AA9FF),
    blobViolet: Color(0x3B9B7BFF),
    ink: Color(0xFF0B0F14),
    onInk: Color(0xFFFFFFFF),
    outline: Color(0xFFB9C6D3),
    outlineVariant: Color(0x80B9C6D3),
    onSurface: Color(0xFF0B0F14),
    onSurfaceVariant: Color(0xFF3E4A57),
    primary: Color(0xFF005A50),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFCCF1EC),
    onPrimaryContainer: Color(0xFF00201D),
    error: Color(0xFF9E2019),
    onError: Color(0xFFFFFFFF),
    disclosure: Color(0xFF734300),
    claims: Color(0xFF9C1246),
    visuals: Color(0xFF1A4AAE),
    borrowed: Color(0xFF5530A3),
    factcheck: Color(0xFF005A50),
    supported: Color(0xFF125A2A),
    contradicted: Color(0xFF9E2019),
    previouslyFactChecked: Color(0xFF1A4AAE),
    insufficientEvidence: Color(0xFF3E4A57),
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
    required this.glassSheen,
    required this.glassEdgeFade,
    required this.blobs,
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
      glassSheen: p.glassSheen,
      glassEdgeFade: p.glassEdgeFade,
      blobs: [p.blobTeal, p.blobSky, p.blobViolet],
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
      // A wide soft shadow for depth and a tight one that seats the card.
      cardShadows: [
        BoxShadow(
          color: p.glassShadow,
          offset: const Offset(0, 12),
          blurRadius: 32,
          spreadRadius: -4,
        ),
        BoxShadow(
          color: p.glassShadow,
          offset: const Offset(0, 1),
          blurRadius: 3,
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
  final Color glassSheen;
  final Color glassEdgeFade;

  /// Background light: teal, sky, violet.
  final List<Color> blobs;
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

/// The team card in About: an aurora behind glass and a gradient name.
abstract final class TeamColors {
  static const auroraTeal = Color(0xFF2EC4B6);
  static const auroraSky = Color(0xFF5AA9FF);
  static const auroraViolet = Color(0xFF9B7BFF);
  static const auroraAlpha = 0.45;

  /// The name runs through these; each passes 4.5:1 on the light glass.
  static const name = [
    Color(0xFF005A50),
    Color(0xFF1A4AAE),
    Color(0xFF5530A3),
    Color(0xFF005A50),
  ];

  /// The glossy band that sweeps across the name.
  static const sheen = Color(0xB3FFFFFF);
}
