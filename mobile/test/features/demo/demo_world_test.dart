import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/features/demo/data/demo_world.dart';

/// Même partage au prorata que le serveur (tests/unit/pricing.test.ts).
void main() {
  test('seul sur tout le trajet : la moitié ; pris à mi-chemin : la moitié de sa portion', () {
    expect(demoProRataShares(108, 10000, [10000]), [54]);
    expect(demoProRataShares(108, 10000, [5000]), [27]);
  });

  test('deux passagers : la portion commune partagée à trois', () {
    expect(demoProRataShares(108, 10000, [10000, 5000]), [45, 18]);
  });

  test('distances bornées au trajet, jamais négatif', () {
    expect(demoProRataShares(108, 10000, [-5, 99000]), [0, 54]);
    expect(demoProRataShares(108, 0, [100]), [0]);
  });
}
