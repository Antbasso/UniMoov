import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/tokens_codegen.dart';

void main() {
  final source = File('../docs/design-system/tokens.json').readAsStringSync();

  test('génère toutes les couleurs des deux thèmes', () {
    final code = generateTokens(source);
    expect(code, contains('static const light = UmColorTokens('));
    expect(code, contains('brand: Color(0xFF7142F2)'));
    expect(code, contains('brand: Color(0xFFA58BFF)'));
    expect(code, contains('static const double s6 = 32;'));
    expect(code, contains('static const double lg = 28;'));
    expect(code, contains('Color(0x297142F2)'));
  });

  test('camel convertit les noms kebab-case', () {
    expect(camel('surface-raised'), 'surfaceRaised');
    expect(camel('body-sm'), 'bodySm');
    expect(camel('ink'), 'ink');
  });

  test('refuse une couleur mal formée', () {
    expect(() => generateTokens(source.replaceFirst('#7142f2', '#7142')), throwsFormatException);
  });
}
