// Génère lib/core/theme/tokens.g.dart depuis docs/design-system/tokens.json.
// Fonction pure : testée pour vérifier que le fichier généré est à jour.
import 'dart:convert';

const _header = '''
// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source : docs/design-system/tokens.json
// Régénérer : dart run tool/generate_tokens.dart
// ignore_for_file: lines_longer_than_80_chars

import 'package:flutter/painting.dart';
''';

String camel(String kebab) {
  final parts = kebab.split('-');
  return parts.first +
      parts.skip(1).map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1)).join();
}

String _colorLiteral(String hex) {
  final value = hex.replaceFirst('#', '').toUpperCase();
  if (value.length != 6) throw FormatException('Couleur inattendue : $hex');
  return 'Color(0xFF$value)';
}

double _px(Object? value) {
  final text = value.toString().trim();
  if (!text.endsWith('px')) throw FormatException('Valeur en px attendue : $text');
  return double.parse(text.substring(0, text.length - 2));
}

String _num(double value) => value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

final _shadowPattern = RegExp(
  r'^(-?\d+)(?:px)? (-?\d+)px (\d+)px (-?\d+)(?:px)? rgba\((\d+),(\d+),(\d+),([\d.]+)\)$',
);

String _shadowLiteral(String css) {
  final m = _shadowPattern.firstMatch(css.trim());
  if (m == null) throw FormatException('Ombre non reconnue : $css');
  final alpha = (double.parse(m.group(8)!) * 255).round();
  String hex2(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
  final color =
      '0x${hex2(alpha)}${hex2(int.parse(m.group(5)!))}${hex2(int.parse(m.group(6)!))}${hex2(int.parse(m.group(7)!))}';
  return 'BoxShadow(offset: Offset(${m.group(1)}, ${m.group(2)}), blurRadius: ${m.group(3)}, spreadRadius: ${m.group(4)}, color: Color($color))';
}

String generateTokens(String json) {
  final root = jsonDecode(json) as Map<String, dynamic>;
  final out = StringBuffer(_header);

  // Couleurs : une ThemeExtension avec une instance par thème.
  final colors = ((root['color'] as Map<String, dynamic>)['tokens'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final names = colors.map((c) => camel(c['name'] as String)).toList();
  out
    ..writeln()
    ..writeln('/// Couleurs Uni-Moov (clair et sombre).')
    ..writeln('class UmColorTokens {')
    ..writeln('  const UmColorTokens({')
    ..writeAll(names.map((n) => '    required this.$n,\n'))
    ..writeln('  });')
    ..writeln();
  for (final c in colors) {
    out
      ..writeln('  /// ${(c['usage'] as String).replaceAll('\n', ' ')}')
      ..writeln('  final Color ${camel(c['name'] as String)};');
  }
  for (final theme in ['light', 'dark']) {
    out
      ..writeln()
      ..writeln('  static const $theme = UmColorTokens(');
    for (final c in colors) {
      final value = (c['value'] as Map<String, dynamic>)[theme] as String;
      out.writeln('    ${camel(c['name'] as String)}: ${_colorLiteral(value)},');
    }
    out.writeln('  );');
  }
  out
    ..writeln()
    ..writeln(
      '  static UmColorTokens lerp(UmColorTokens a, UmColorTokens b, double t) => UmColorTokens(',
    )
    ..writeAll(names.map((n) => '    $n: Color.lerp(a.$n, b.$n, t)!,\n'))
    ..writeln('  );')
    ..writeln('}');

  // Espacements.
  out
    ..writeln()
    ..writeln('/// Échelle d’espacement (px logiques).')
    ..writeln('abstract final class UmSpace {');
  for (final s
      in ((root['spacing'] as Map<String, dynamic>)['tokens'] as List<dynamic>)
          .cast<Map<String, dynamic>>()) {
    out.writeln(
      '  static const double ${camel((s['name'] as String).replaceFirst('space-', 's'))} = ${_num(_px(s['value']))};',
    );
  }
  out.writeln('}');

  // Rayons.
  out
    ..writeln()
    ..writeln('/// Rayons d’arrondi.')
    ..writeln('abstract final class UmRadius {');
  for (final r
      in ((root['radius'] as Map<String, dynamic>)['tokens'] as List<dynamic>)
          .cast<Map<String, dynamic>>()) {
    out.writeln(
      '  static const double ${camel((r['name'] as String).replaceFirst('radius-', ''))} = ${_num(_px(r['value']))};',
    );
  }
  out.writeln('}');

  // Ombres.
  out
    ..writeln()
    ..writeln('/// Ombres par thème.')
    ..writeln('abstract final class UmShadowTokens {');
  for (final s
      in ((root['shadow'] as Map<String, dynamic>)['tokens'] as List<dynamic>)
          .cast<Map<String, dynamic>>()) {
    final value = s['value'] as Map<String, dynamic>;
    for (final theme in ['light', 'dark']) {
      final name = camel('${(s['name'] as String).replaceFirst('shadow-', '')}-$theme');
      out.writeln('  static const $name = [${_shadowLiteral(value[theme] as String)}];');
    }
  }
  out.writeln('}');

  // Typographie.
  final type = root['type'] as Map<String, dynamic>;
  final families = (type['families'] as Map<String, dynamic>).map(
    (key, value) => MapEntry(key, _firstFamily(value as String)),
  );
  out
    ..writeln()
    ..writeln('/// Familles de polices (premier choix de chaque pile CSS).')
    ..writeln('abstract final class UmFontFamily {');
  families.forEach((key, value) => out.writeln("  static const $key = '$value';"));
  out
    ..writeln('}')
    ..writeln()
    ..writeln('/// Style typographique brut (taille, interligne, graisse, approche).')
    ..writeln('class UmTypeToken {')
    ..writeln(
      '  const UmTypeToken({required this.family, required this.fontSize, required this.lineHeight, required this.fontWeight, this.letterSpacingEm = 0});',
    )
    ..writeln('  final String family;')
    ..writeln('  final double fontSize;')
    ..writeln('  final double lineHeight;')
    ..writeln('  final FontWeight fontWeight;')
    ..writeln('  final double letterSpacingEm;')
    ..writeln('}')
    ..writeln()
    ..writeln('abstract final class UmTypeTokens {');
  for (final group in (type['groups'] as List<dynamic>).cast<Map<String, dynamic>>()) {
    for (final style in (group['styles'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      final spacing = style['letterSpacing'] as String?;
      final em = spacing == null ? 0.0 : double.parse(spacing.replaceFirst('em', ''));
      out
        ..writeln('  /// ${(style['usage'] as String).replaceAll('\n', ' ')}')
        ..writeln('  static const ${camel(style['name'] as String)} = UmTypeToken(')
        ..writeln('    family: UmFontFamily.${group['family']},')
        ..writeln('    fontSize: ${_num(_px(style['fontSize']))},')
        ..writeln('    lineHeight: ${_num(_px(style['lineHeight']))},')
        ..writeln('    fontWeight: FontWeight.w${style['fontWeight']},')
        ..writeln(em == 0 ? '  );' : '    letterSpacingEm: $em,\n  );');
    }
  }
  out.writeln('}');
  return out.toString();
}

String _firstFamily(String cssStack) => cssStack.split(',').first.trim().replaceAll('"', '');
