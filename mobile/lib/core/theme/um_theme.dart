import 'package:flutter/material.dart';

import 'tokens.g.dart';

export 'tokens.g.dart';
export 'um_sizes.dart';

/// Couleurs du thème courant, accessibles via `context.umColors`.
class UmColors extends ThemeExtension<UmColors> {
  const UmColors(this.tokens, this.shadowSoft);

  final UmColorTokens tokens;
  final List<BoxShadow> shadowSoft;

  static const light = UmColors(UmColorTokens.light, UmShadowTokens.softLight);
  static const dark = UmColors(UmColorTokens.dark, UmShadowTokens.softDark);

  @override
  UmColors copyWith({UmColorTokens? tokens, List<BoxShadow>? shadowSoft}) =>
      UmColors(tokens ?? this.tokens, shadowSoft ?? this.shadowSoft);

  @override
  UmColors lerp(UmColors? other, double t) {
    if (other == null) return this;
    return UmColors(
      UmColorTokens.lerp(tokens, other.tokens, t),
      BoxShadow.lerpList(shadowSoft, other.shadowSoft, t)!,
    );
  }
}

/// Styles de texte du design system, sans couleur (héritée du contexte).
abstract final class UmText {
  static TextStyle of(UmTypeToken token) => TextStyle(
    fontFamily: token.family,
    fontSize: token.fontSize,
    height: token.lineHeight / token.fontSize,
    fontWeight: token.fontWeight,
    letterSpacing: token.letterSpacingEm * token.fontSize,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static final display = of(UmTypeTokens.display);
  static final h1 = of(UmTypeTokens.h1);
  static final h2 = of(UmTypeTokens.h2);
  static final h3 = of(UmTypeTokens.h3);
  static final body = of(UmTypeTokens.body);
  static final bodySm = of(UmTypeTokens.bodySm);
  static final label = of(UmTypeTokens.label);
  static final caption = of(UmTypeTokens.caption);
  static final note = of(UmTypeTokens.note);

  /// Libellé de bouton : texte courant en 600 (16/24, components.css `.um-btn`).
  static final button = body.copyWith(fontWeight: FontWeight.w600);
}

extension UmThemeContext on BuildContext {
  UmColorTokens get umColors => Theme.of(this).extension<UmColors>()!.tokens;
  List<BoxShadow> get umShadowSoft => Theme.of(this).extension<UmColors>()!.shadowSoft;
}

/// Construit le ThemeData Material à partir des tokens.
ThemeData buildUmTheme(Brightness brightness) {
  final ext = brightness == Brightness.light ? UmColors.light : UmColors.dark;
  final c = ext.tokens;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.brand,
    onPrimary: c.onBrand,
    primaryContainer: c.lavender,
    onPrimaryContainer: c.brandStrong,
    secondary: c.brandStrong,
    onSecondary: c.surface,
    surface: c.surface,
    onSurface: c.ink,
    onSurfaceVariant: c.inkMuted,
    surfaceContainerLowest: c.surfaceRaised,
    surfaceContainerLow: c.surfaceRaised,
    surfaceContainer: c.surfaceTint,
    surfaceContainerHigh: c.surfaceTint,
    surfaceContainerHighest: c.lavender,
    outline: c.borderControl,
    outlineVariant: c.border,
    error: c.danger,
    onError: c.surface,
    errorContainer: c.dangerSoft,
    onErrorContainer: c.danger,
  );

  // Les 15 styles Material pointent vers l'échelle du design system : aucun widget Material
  // (dialogue, menu, barre d'app) ne peut afficher une taille hors échelle.
  final textTheme = TextTheme(
    displayLarge: UmText.display,
    displayMedium: UmText.h1,
    displaySmall: UmText.h1,
    headlineLarge: UmText.h1,
    headlineMedium: UmText.h2,
    headlineSmall: UmText.h2,
    titleLarge: UmText.h3,
    titleMedium: UmText.h3,
    titleSmall: UmText.label,
    bodyLarge: UmText.body,
    bodyMedium: UmText.bodySm,
    bodySmall: UmText.caption,
    labelLarge: UmText.button,
    labelMedium: UmText.label,
    labelSmall: UmText.caption,
  ).apply(bodyColor: c.ink, displayColor: c.ink);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.surface,
    fontFamily: UmFontFamily.sans,
    textTheme: textTheme,
    // Surbrillance de focus des composants Material (listes, icônes, interrupteurs) bien visible.
    focusColor: c.focus.withValues(alpha: 0.24),
    materialTapTargetSize: MaterialTapTargetSize.padded,
    extensions: [ext],
  );
}
