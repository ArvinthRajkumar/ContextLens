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
  for (final p in [AppPalette.dark, AppPalette.light]) {
    group('${p.brightness.name} palette', () {
      final surfaces = {
        'background': p.background,
        'surface': p.surface,
        'surfaceContainer': p.surfaceContainer,
        'surfaceContainerHigh': p.surfaceContainerHigh,
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
        'onPrimary on primary': (p.onPrimary, p.primary),
        'onPrimaryContainer on primaryContainer': (
          p.onPrimaryContainer,
          p.primaryContainer,
        ),
        'onError on error': (p.onError, p.error),
        'surface on onSurface (snackbar)': (p.surface, p.onSurface),
      };
      for (final pair in pairs.entries) {
        test('${pair.key} >= $_text', () {
          final (fg, bg) = pair.value;
          expect(contrast(fg, bg), greaterThanOrEqualTo(_text));
        });
      }
    });
  }
}
