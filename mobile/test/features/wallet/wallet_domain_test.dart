import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/features/wallet/domain/wallet.dart';

void main() {
  test('montant en euros saisi : centimes entiers, virgule ou point', () {
    expect(parseEurosToCents('12'), 1200);
    expect(parseEurosToCents('12,5'), 1250);
    expect(parseEurosToCents('12.05'), 1205);
    expect(parseEurosToCents(' 1 200,99 '), 120099);
    expect(parseEurosToCents('0,01'), 1);
  });

  test('montant refusé : vide, nul, négatif, trop de décimales, texte', () {
    for (final input in ['', '0', '0,00', '-5', '12,345', 'douze', '12,', ',5', '1e3']) {
      expect(parseEurosToCents(input), isNull, reason: input);
    }
  });
}
