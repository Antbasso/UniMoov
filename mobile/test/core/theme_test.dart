import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/core/theme/um_theme.dart';

double _luminance(Color c) => c.computeLuminance();

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  for (final (name, tokens) in [('clair', UmColorTokens.light), ('sombre', UmColorTokens.dark)]) {
    group('contrastes du thème $name', () {
      // Paires texte/fond déclarées dans tokens.json (champ `usage`).
      final pairs = <String, (Color, Color)>{
        'ink/surface': (tokens.ink, tokens.surface),
        'ink/surfaceRaised': (tokens.ink, tokens.surfaceRaised),
        'ink/surfaceTint': (tokens.ink, tokens.surfaceTint),
        'ink/lavender': (tokens.ink, tokens.lavender),
        'inkMuted/surface': (tokens.inkMuted, tokens.surface),
        'inkMuted/surfaceRaised': (tokens.inkMuted, tokens.surfaceRaised),
        'inkMuted/surfaceTint': (tokens.inkMuted, tokens.surfaceTint),
        'onBrand/brand': (tokens.onBrand, tokens.brand),
        'brandStrong/surface': (tokens.brandStrong, tokens.surface),
        'brandStrong/surfaceRaised': (tokens.brandStrong, tokens.surfaceRaised),
        'brandStrong/lavender': (tokens.brandStrong, tokens.lavender),
        'success/successSoft': (tokens.success, tokens.successSoft),
        'danger/dangerSoft': (tokens.danger, tokens.dangerSoft),
        'danger/surfaceRaised': (tokens.danger, tokens.surfaceRaised),
      };
      pairs.forEach((pair, colors) {
        test(
          '$pair ≥ 4.5:1',
          () => expect(contrast(colors.$1, colors.$2), greaterThanOrEqualTo(4.5)),
        );
      });
      test('borderControl ≥ 3:1 sur surface', () {
        expect(contrast(tokens.borderControl, tokens.surface), greaterThanOrEqualTo(3));
      });
    });
  }

  test('le ThemeData reprend les tokens', () {
    final light = buildUmTheme(Brightness.light);
    final dark = buildUmTheme(Brightness.dark);
    expect(light.colorScheme.primary, UmColorTokens.light.brand);
    expect(dark.colorScheme.primary, UmColorTokens.dark.brand);
    expect(light.scaffoldBackgroundColor, UmColorTokens.light.surface);
    expect(dark.scaffoldBackgroundColor, UmColorTokens.dark.surface);
    expect(light.extension<UmColors>()!.tokens, same(UmColorTokens.light));
    expect(light.textTheme.headlineLarge!.fontFamily, UmFontFamily.display);
    expect(light.textTheme.bodyLarge!.fontFamily, UmFontFamily.sans);
  });

  test('les 15 styles Material sont dans l’échelle du design system', () {
    final scale = {
      for (final t in [
        UmText.display,
        UmText.h1,
        UmText.h2,
        UmText.h3,
        UmText.body,
        UmText.bodySm,
        UmText.label,
        UmText.caption,
        UmText.button,
      ])
        (t.fontFamily, t.fontSize, t.fontWeight),
    };
    final theme = buildUmTheme(Brightness.light).textTheme;
    final styles = [
      theme.displayLarge,
      theme.displayMedium,
      theme.displaySmall,
      theme.headlineLarge,
      theme.headlineMedium,
      theme.headlineSmall,
      theme.titleLarge,
      theme.titleMedium,
      theme.titleSmall,
      theme.bodyLarge,
      theme.bodyMedium,
      theme.bodySmall,
      theme.labelLarge,
      theme.labelMedium,
      theme.labelSmall,
    ];
    for (final style in styles) {
      expect(scale, contains((style!.fontFamily, style.fontSize, style.fontWeight)));
    }
  });

  test('styles de texte : taille et interligne des tokens', () {
    expect(UmText.h1.fontSize, 36);
    expect(UmText.h1.height! * UmText.h1.fontSize!, closeTo(42, 0.001));
    expect(UmText.display.letterSpacing, closeTo(-1.12, 0.001));
    expect(UmText.note.fontFamily, 'Caveat');
  });
}
