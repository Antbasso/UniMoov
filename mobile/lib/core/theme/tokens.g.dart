// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source : docs/design-system/tokens.json
// Régénérer : dart run tool/generate_tokens.dart
// ignore_for_file: lines_longer_than_80_chars

import 'package:flutter/painting.dart';

/// Couleurs Uni-Moov (clair et sombre).
class UmColorTokens {
  const UmColorTokens({
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceTint,
    required this.lavender,
    required this.ink,
    required this.inkMuted,
    required this.brand,
    required this.brandStrong,
    required this.brandTop,
    required this.brandBottom,
    required this.onBrand,
    required this.border,
    required this.borderControl,
    required this.focus,
    required this.success,
    required this.successSoft,
    required this.danger,
    required this.dangerSoft,
  });

  /// Fond de page et d'affiche (blanc légèrement lavande). Texte : `ink`, `ink-muted`, `brand-strong`.
  final Color surface;

  /// Cartes, champs, feuilles flottantes posées sur `surface`. Texte : `ink`, `ink-muted`.
  final Color surfaceRaised;

  /// Aplats d'ambiance (bandeaux, zones secondaires) sur `surface`. Texte : `ink`, `brand-strong`.
  final Color surfaceTint;

  /// Pastille « sticker » et cadre du QR code de l'affiche, puces. Texte : `brand-strong`, `ink`.
  final Color lavender;

  /// Titres et texte courant (marine très sombre de l'affiche) sur `surface`, `surface-raised`, `surface-tint`, `lavender`.
  final Color ink;

  /// Texte secondaire, légendes et aides sur `surface`, `surface-raised`, `surface-tint`.
  final Color inkMuted;

  /// Violet Uni-Moov : fond des boutons principaux, icônes pleines, logo. Texte dessus : `on-brand`.
  final Color brand;

  /// Violet profond de l'affiche : sous-titres, liens, icônes au trait, état pressé des boutons, bandeau de pied d'affiche. Lisible sur `surface`, `surface-raised`, `surface-tint`, `lavender`.
  final Color brandStrong;

  /// Haut du dégradé de la tache du logo et dos des collines de l'affiche. Décoratif, jamais de texte dessus.
  final Color brandTop;

  /// Bas du dégradé de la tache du logo. Décoratif, jamais de texte dessus.
  final Color brandBottom;

  /// Texte et icônes posés sur `brand`.
  final Color onBrand;

  /// Filets décoratifs et séparateurs de cartes (non porteurs de sens).
  final Color border;

  /// Bordure des champs et boutons secondaires, 3:1 minimum sur `surface` et `surface-raised`.
  final Color borderControl;

  /// Anneau de focus clavier, 3 px pleins, jamais retiré.
  final Color focus;

  /// Texte et icône de succès (trajet confirmé), toujours accompagné d'un mot ou d'une icône. Sur `surface`, `surface-raised`, `success-soft`.
  final Color success;

  /// Fond des puces de succès.
  final Color successSoft;

  /// Texte et icône d'erreur ou d'annulation, toujours accompagné d'un mot ou d'une icône. Sur `surface`, `surface-raised`, `danger-soft`.
  final Color danger;

  /// Fond des puces d'erreur.
  final Color dangerSoft;

  static const light = UmColorTokens(
    surface: Color(0xFFFCFBFF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceTint: Color(0xFFF3EEFF),
    lavender: Color(0xFFE3D9FD),
    ink: Color(0xFF16143A),
    inkMuted: Color(0xFF5A5878),
    brand: Color(0xFF7142F2),
    brandStrong: Color(0xFF5B3FCC),
    brandTop: Color(0xFF9460F8),
    brandBottom: Color(0xFF6B3FF5),
    onBrand: Color(0xFFFFFFFF),
    border: Color(0xFFE3D9FD),
    borderControl: Color(0xFF7A5FD9),
    focus: Color(0xFF5B3FCC),
    success: Color(0xFF0B6B45),
    successSoft: Color(0xFFDFF5EA),
    danger: Color(0xFFB3203F),
    dangerSoft: Color(0xFFFDE6EA),
  );

  static const dark = UmColorTokens(
    surface: Color(0xFF14122F),
    surfaceRaised: Color(0xFF1E1B45),
    surfaceTint: Color(0xFF25215A),
    lavender: Color(0xFF332D7A),
    ink: Color(0xFFF4F1FF),
    inkMuted: Color(0xFFB9B5D9),
    brand: Color(0xFFA58BFF),
    brandStrong: Color(0xFFC8B8FF),
    brandTop: Color(0xFF7A5AE0),
    brandBottom: Color(0xFF5A37D6),
    onBrand: Color(0xFF14122F),
    border: Color(0xFF3E3880),
    borderControl: Color(0xFF8B78D8),
    focus: Color(0xFFC8B8FF),
    success: Color(0xFF5FD6A0),
    successSoft: Color(0xFF12382B),
    danger: Color(0xFFFF8AA1),
    dangerSoft: Color(0xFF4A1A2A),
  );

  static UmColorTokens lerp(UmColorTokens a, UmColorTokens b, double t) => UmColorTokens(
    surface: Color.lerp(a.surface, b.surface, t)!,
    surfaceRaised: Color.lerp(a.surfaceRaised, b.surfaceRaised, t)!,
    surfaceTint: Color.lerp(a.surfaceTint, b.surfaceTint, t)!,
    lavender: Color.lerp(a.lavender, b.lavender, t)!,
    ink: Color.lerp(a.ink, b.ink, t)!,
    inkMuted: Color.lerp(a.inkMuted, b.inkMuted, t)!,
    brand: Color.lerp(a.brand, b.brand, t)!,
    brandStrong: Color.lerp(a.brandStrong, b.brandStrong, t)!,
    brandTop: Color.lerp(a.brandTop, b.brandTop, t)!,
    brandBottom: Color.lerp(a.brandBottom, b.brandBottom, t)!,
    onBrand: Color.lerp(a.onBrand, b.onBrand, t)!,
    border: Color.lerp(a.border, b.border, t)!,
    borderControl: Color.lerp(a.borderControl, b.borderControl, t)!,
    focus: Color.lerp(a.focus, b.focus, t)!,
    success: Color.lerp(a.success, b.success, t)!,
    successSoft: Color.lerp(a.successSoft, b.successSoft, t)!,
    danger: Color.lerp(a.danger, b.danger, t)!,
    dangerSoft: Color.lerp(a.dangerSoft, b.dangerSoft, t)!,
  );
}

/// Échelle d’espacement (px logiques).
abstract final class UmSpace {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 24;
  static const double s6 = 32;
  static const double s7 = 48;
  static const double s8 = 64;
}

/// Rayons d’arrondi.
abstract final class UmRadius {
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 28;
  static const double pill = 999;
}

/// Ombres par thème.
abstract final class UmShadowTokens {
  static const softLight = [
    BoxShadow(offset: Offset(0, 8), blurRadius: 24, spreadRadius: 0, color: Color(0x297142F2)),
  ];
  static const softDark = [
    BoxShadow(offset: Offset(0, 8), blurRadius: 24, spreadRadius: 0, color: Color(0x80000000)),
  ];
}

/// Familles de polices (premier choix de chaque pile CSS).
abstract final class UmFontFamily {
  static const display = 'UniMoov Display';
  static const sans = 'Poppins';
  static const hand = 'Caveat';
}

/// Style typographique brut (taille, interligne, graisse, approche).
class UmTypeToken {
  const UmTypeToken({
    required this.family,
    required this.fontSize,
    required this.lineHeight,
    required this.fontWeight,
    this.letterSpacingEm = 0,
  });
  final String family;
  final double fontSize;
  final double lineHeight;
  final FontWeight fontWeight;
  final double letterSpacingEm;
}

abstract final class UmTypeTokens {
  /// Accroche d'affiche et héros de page, en `ink`.
  static const display = UmTypeToken(
    family: UmFontFamily.display,
    fontSize: 56,
    lineHeight: 60,
    fontWeight: FontWeight.w600,
    letterSpacingEm: -0.02,
  );

  /// Titre d'écran.
  static const h1 = UmTypeToken(
    family: UmFontFamily.display,
    fontSize: 36,
    lineHeight: 42,
    fontWeight: FontWeight.w600,
    letterSpacingEm: -0.01,
  );

  /// Sous-titre en `brand-strong` ou `ink`.
  static const h2 = UmTypeToken(
    family: UmFontFamily.display,
    fontSize: 26,
    lineHeight: 32,
    fontWeight: FontWeight.w600,
  );

  /// Titre de carte.
  static const h3 = UmTypeToken(
    family: UmFontFamily.display,
    fontSize: 18,
    lineHeight: 24,
    fontWeight: FontWeight.w600,
  );

  /// Texte courant.
  static const body = UmTypeToken(
    family: UmFontFamily.sans,
    fontSize: 16,
    lineHeight: 24,
    fontWeight: FontWeight.w400,
  );

  /// Texte de carte, légendes longues.
  static const bodySm = UmTypeToken(
    family: UmFontFamily.sans,
    fontSize: 14,
    lineHeight: 20,
    fontWeight: FontWeight.w400,
  );

  /// Libellés de champs et puces. Les boutons utilisent `body` en 600 (16/24 px, voir components.css `.um-btn`).
  static const label = UmTypeToken(
    family: UmFontFamily.sans,
    fontSize: 14,
    lineHeight: 20,
    fontWeight: FontWeight.w600,
  );

  /// Légendes sous icône, mentions.
  static const caption = UmTypeToken(
    family: UmFontFamily.sans,
    fontSize: 12,
    lineHeight: 16,
    fontWeight: FontWeight.w500,
  );

  /// Annotation « sticker » à la main, en `brand-strong` sur `lavender`, 24 px minimum. Une par écran ou affiche.
  static const note = UmTypeToken(
    family: UmFontFamily.hand,
    fontSize: 26,
    lineHeight: 28,
    fontWeight: FontWeight.w600,
  );
}
