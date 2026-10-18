import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/app.dart';
import 'package:unimoov/core/clock.dart';
import 'package:unimoov/core/location/location_service.dart';
import 'package:unimoov/core/storage/token_storage.dart';
import 'package:unimoov/features/account/data/export_sharer.dart';
import 'package:unimoov/features/demo/demo_mode.dart';
import 'package:unimoov/features/rides/data/nav_launcher.dart';
import 'package:unimoov/features/rides/presentation/ride_map.dart';

import '../../support/app_harness.dart';
import '../../support/chat_fakes.dart';
import '../../support/live_fakes.dart';

void main() {
  final realStorage = MemoryTokenStorage();

  Future<void> launch(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    // Animations en boucle (trajet en cours) coupées, comme avec le réglage d'accessibilité.
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Comme en vrai : stockage de la démo pendant la démo, sinon celui de l'appareil.
          tokenStorageProvider.overrideWith(
            (ref) => ref.watch(demoProvider) == null
                ? realStorage
                : ref.read(demoProvider.notifier).storage,
          ),
          locationServiceProvider.overrideWithValue(FakeLocationService()),
          navLauncherProvider.overrideWithValue(FakeNavLauncher()),
          exportSharerProvider.overrideWithValue(FakeExportSharer()),
          clockProvider.overrideWithValue(() => testNow),
          rasterTilesEnabledProvider.overrideWithValue(false),
        ],
        child: const UniMoovApp(themeMode: ThemeMode.light),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('démo : compte prêt, semaine remplie, trajet en cours simulé, puis sortie', (
    tester,
  ) async {
    await launch(tester);
    await tapText(tester, 'Essayer la démo');
    await tapText(tester, 'Compte prêt : Camille');
    expect(find.byType(Banner), findsOneWidget);
    expect(find.text('Ta semaine'), findsOneWidget);

    // Trajet en cours : Nathan approche, la présence se valide à la prise en charge.
    // Mercredi : deux trajets terminés ; jeudi (aujourd'hui) : le trajet en cours d'abord.
    await tapText(tester, 'Voir', index: 2);
    await tapText(tester, 'Voir la carte');
    expect(find.text('Trajet en cours'), findsOneWidget);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(seconds: 2));
    }
    await tester.pumpAndSettle();
    expect(find.text('Présence validée : ta part est prélevée à l\'arrivée'), findsOneWidget);

    // Quitter la carte : le suivi se ferme, plus aucune minuterie.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
    expect(realStorage.tokens, isNull);
  });

  testWidgets('démo : parcours d’inscription avec le code affiché', (tester) async {
    await launch(tester);
    await tapText(tester, 'Essayer la démo');
    await tapText(tester, 'Parcours d\'inscription');
    await tester.enterText(find.byType(TextField).first, 'sam.doe@etu.univ-smb.fr');
    await tester.pumpAndSettle();
    await tapText(tester, 'Recevoir mon code');
    expect(find.text('Démo : le code est 123456.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
