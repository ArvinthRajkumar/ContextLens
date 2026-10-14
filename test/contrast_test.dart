import 'dart:math' as math;

import 'package:contextlens/core/theme/colors.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.x contrast ratio.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

const double _text = 4.5;

void main() {
  const p = AppPalette.light;

  // Text sits on the sky gradient or on glass over it. The sky top is the
  // darkest point, so glass over it is the worst case for glass.
  final surfaces = {
    'skyTop': p.skyTop,
    'skyMid': p.skyMid,
    'skyBottom': p.skyBottom,
    'glass on sky': p.glassOnSky,
    'faint glass on sky': Color.alphaBlend(p.glassFaint, p.skyTop),
    'strong glass on sky': Color.alphaBlend(p.glassStrong, p.skyTop),
    // The background light pools, at their strongest, under faint glass.
    for (final (name, blob) in [
      ('teal', p.blobTeal),
      ('sky', p.blobSky),
      ('violet', p.blobViolet),
    ]) ...{
      '$name light on sky': Color.alphaBlend(blob, p.skyTop),
      'faint glass on $name light': Color.alphaBlend(
        p.glassFaint,
        Color.alphaBlend(blob, p.skyTop),
      ),
    },
  };

  // Every foreground that renders as text or an icon on app surfaces.
  final foregrounds = {
    'onSurface': p.onSurface,
    'onSurfaceVariant': p.onSurfaceVariant,
    'primary': p.primary,
    'error': p.error,
    'disclosure': p.disclosure,
    'claims': p.claims,
    'visuals': p.visuals,
    'borrowed': p.borrowed,
    'factcheck': p.factcheck,
    'supported': p.supported,
    'contradicted': p.contradicted,
    'previouslyFactChecked': p.previouslyFactChecked,
    'insufficientEvidence': p.insufficientEvidence,
  };

  for (final fg in foregrounds.entries) {
    for (final bg in surfaces.entries) {
      test('${fg.key} on ${bg.key} >= $_text', () {
        expect(contrast(fg.value, bg.value), greaterThanOrEqualTo(_text));
      });
    }
  }

  final pairs = {
    'onInk on ink (primary button)': (p.onInk, p.ink),
    'onPrimary on primary': (p.onPrimary, p.primary),
    'onPrimaryContainer on primaryContainer': (
      p.onPrimaryContainer,
      p.primaryContainer,
    ),
    'onError on error': (p.onError, p.error),
  };
  for (final pair in pairs.entries) {
    test('${pair.key} >= $_text', () {
      final (fg, bg) = pair.value;
      expect(contrast(fg, bg), greaterThanOrEqualTo(_text));
    });
  }

  // The team name sits on faint glass over the aurora, worst case where a
  // pool of light is at full strength.
  for (final aurora in [
    TeamColors.auroraTeal,
    TeamColors.auroraSky,
    TeamColors.auroraViolet,
  ]) {
    final behind = Color.alphaBlend(
      p.glassFaint,
      Color.alphaBlend(
        aurora.withValues(alpha: TeamColors.auroraAlpha),
        p.skyBottom,
      ),
    );
    for (final name in TeamColors.name.toSet()) {
      test('team name $name on aurora $aurora >= 3', () {
        // Large display text: 3:1 is the WCAG bar.
        expect(contrast(name, behind), greaterThanOrEqualTo(3));
      });
    }
  }
}
