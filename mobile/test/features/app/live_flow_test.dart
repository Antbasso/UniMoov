import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/core/api/api_client.dart';
import 'package:unimoov/core/location/location_service.dart';
import 'package:unimoov/core/storage/token_storage.dart';
import 'package:unimoov/features/auth/domain/auth_tokens.dart';
import 'package:unimoov/features/rides/domain/ride.dart';

import '../../support/app_harness.dart';
import '../../support/fake_backend.dart';
import '../../support/live_fakes.dart';

const me = 'id-lea@etu.univ-smb.fr';

void main() {
  late FakeBackend backend;
  late MemoryTokenStorage storage;
  late FakeLiveConnector live;
  late FakeLocationService location;
  late FakeNavLauncher launcher;
  late DateTime now;

  setUp(() {
    backend = rideBackend();
    storage = MemoryTokenStorage()..tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
    live = FakeLiveConnector();
    location = FakeLocationService();
    launcher = FakeNavLauncher();
    // Semaine des propositions du faux backend (jeudi 15 octobre, comme les autres tests).
    now = testNow;
  });

  Future<void> launch(WidgetTester tester, {ThemeMode mode = ThemeMode.light}) => launchApp(
    tester,
    backend: backend,
    storage: storage,
    themeMode: mode,
    clock: () => now,
    live: live,
    location: location,
    launcher: launcher,
  );

  Future<void> openDeparture(WidgetTester tester) async {
    await launch(tester);
    await openTrip(tester, index: 1);
    await tapText(tester, 'Écran de départ');
  }

  group('conducteur', () {
    testWidgets('démarrer : explication puis permission, le suivi s’ouvre et la position part', (
      tester,
    ) async {
      await openDeparture(tester);
      expect(find.text('Départ'), findsOneWidget);
      expect(find.text('Destination'), findsOneWidget);
      await tapText(tester, 'Démarrer le trajet');

      expect(find.text('Partage ta position pendant le trajet'), findsOneWidget);
      expect(location.requests, 0); // pas de demande système avant l'explication
      await tapText(tester, 'Autoriser la position');
      expect(location.requests, 1);
      expect(backend.actions, ['start:ride-2']);
      expect(find.text('Trajet en cours'), findsOneWidget);
      expect(live.connections, hasLength(1));

      location.positionsController.add((lat: 45.87, lon: 6.14, at: now));
      await tester.pump();
      expect(live.last.sent, [(lat: 45.87, lon: 6.14)]);
    });

    testWidgets('navigation : choix de l’app mémorisé, Google Maps avec tous les arrêts', (
      tester,
    ) async {
      await backend.start('ride-2');
      await openDeparture(tester);
      await tapText(tester, 'Lancer la navigation');
      expect(find.text('Avec quelle application ?'), findsOneWidget);
      await tapText(tester, 'Google Maps');

      final link = launcher.opened.single;
      expect(link.host, 'www.google.com');
      expect(link.queryParameters['waypoints'], '45.900000,6.120000|45.905000,6.103000');
      expect(link.queryParameters['destination'], '45.919500,6.158000');
      expect(backend.actions.where((a) => a == 'start:ride-2'), hasLength(1));

      // Deuxième lancement : plus de question, l'app choisie s'ouvre.
      await tapText(tester, 'Lancer la navigation');
      expect(find.text('Avec quelle application ?'), findsNothing);
      expect(launcher.opened, hasLength(2));
    });

    testWidgets('Waze : arrêt par arrêt ; « monté » fait passer à l’arrêt suivant', (tester) async {
      await backend.start('ride-2');
      await openDeparture(tester);
      await tapText(tester, 'Changer d\'application GPS');
      await tapText(tester, 'Waze');
      expect(launcher.opened.last.toString(), contains('ll=45.900000,6.120000'));
      expect(find.text('Arrêt suivant'), findsOneWidget);
      expect(find.textContaining('Waze ne prend qu\'une destination'), findsOneWidget);

      await tapText(tester, 'Monté à bord', index: 0);
      expect(backend.actions.last, 'picked_up:passenger-2');
      expect(find.text('Monté'), findsOneWidget);
      await tapText(tester, 'Arrêt suivant');
      expect(launcher.opened.last.toString(), contains('ll=45.905000,6.103000'));
    });

    testWidgets('aucune application GPS ou ouverture impossible : message clair', (tester) async {
      await backend.start('ride-2');
      launcher.succeed = false;
      await openDeparture(tester);
      await tapText(tester, 'Lancer la navigation');
      await tapText(tester, 'Google Maps');
      expect(find.text('Impossible d\'ouvrir l\'application GPS.'), findsOneWidget);
    });

    testWidgets('terminer le trajet', (tester) async {
      await backend.start('ride-2');
      await openDeparture(tester);
      await tapText(tester, 'Terminer le trajet');
      expect(find.text('Terminer le trajet ?'), findsOneWidget);
      await tapText(tester, 'Continuer le trajet');
      expect(backend.actions, isNot(contains('finish')));
      await tapText(tester, 'Terminer le trajet');
      await tapText(tester, 'Terminer le trajet', index: 1); // bouton du dialogue
      expect(backend.actions.last, 'finish');
    });

    testWidgets('démarrer trop tôt : erreur du serveur affichée', (tester) async {
      await openDeparture(tester);
      backend.failNext = const ApiException('too_early', '', statusCode: 409);
      await tapText(tester, 'Démarrer le trajet');
      expect(find.text('Trop tôt pour démarrer ce trajet.'), findsOneWidget);
    });
  });

  group('passagère', () {
    Future<void> openLive(WidgetTester tester, {ThemeMode mode = ThemeMode.light}) async {
      await backend.start('ride-1');
      await launch(tester, mode: mode);
      await openTrip(tester, index: 0);
    }

    testWidgets('voit le conducteur arriver, puis « dernière position connue » après 30 s', (
      tester,
    ) async {
      await openLive(tester);
      expect(find.text('En cours'), findsOneWidget);
      live.last
        ..emit(const LiveReady())
        ..emit(LivePosition(userId: 'driver-1', lat: 45.88, lon: 6.13, at: now))
        ..emit(LiveEta(userId: me, eta: now.add(const Duration(minutes: 4))));
      await tester.pumpAndSettle();
      expect(find.textContaining('Le conducteur arrive vers'), findsOneWidget);

      now = now.add(const Duration(seconds: 40));
      await tester.pump(const Duration(seconds: 11));
      expect(find.textContaining('Dernière position connue à'), findsOneWidget);
    });

    testWidgets('valider sa présence : paiement à l’arrivée annoncé', (tester) async {
      await openLive(tester);
      // Pas encore à bord : renoncer, c'est annuler sa place.
      expect(find.byTooltip("Plus d'actions"), findsOneWidget); // « Annuler ma place »
      expect(find.text('Terminer mon trajet'), findsNothing);
      await tapText(tester, 'Valider ma présence');
      expect(backend.actions.last, 'presence');
      expect(find.text('Présence validée. Bon trajet.'), findsOneWidget);
      expect(
        find.text('Présence validée : ta part est prélevée à la fin du trajet'),
        findsOneWidget,
      );
      expect(find.text('Valider ma présence'), findsNothing);
      expect(find.byTooltip("Plus d'actions"), findsNothing);
    });

    testWidgets(
      'terminer son trajet avant l’arrivée : avertissement, puis le conducteur est prévenu',
      (tester) async {
        await openLive(tester);
        await tapText(tester, 'Valider ma présence');
        await tester.pump(const Duration(seconds: 5)); // le message disparaît
        await tester.pumpAndSettle();
        await tapText(tester, 'Terminer mon trajet');
        expect(find.textContaining('ta part reste due'), findsOneWidget);
        await tapText(tester, 'Continuer le trajet');
        expect(backend.actions, isNot(contains('finish')));

        await tapText(tester, 'Terminer mon trajet');
        await tapText(tester, 'Terminer quand même');
        expect(backend.actions.last, 'finish');
        expect(find.text('Trajet terminé. Le conducteur est prévenu.'), findsOneWidget);
        expect(
          find.textContaining('avant la destination prévue : ta part est prélevée'),
          findsOneWidget,
        );
        expect(find.text('Terminer mon trajet'), findsNothing);
      },
    );

    testWidgets('partager sa position ; refus définitif : lien vers les réglages', (tester) async {
      location.onRequest = LocationAccess.deniedForever;
      await openLive(tester);
      await tapText(tester, 'Partager ma position');
      await tapText(tester, 'Autoriser la position');
      expect(find.textContaining('Active-la pour Uni-Moov'), findsOneWidget);
      await tapText(tester, 'Ouvrir les réglages');
      expect(location.settingsOpened, 1);
      await tapText(tester, 'Plus tard');
      expect(find.text('Partager ma position'), findsOneWidget);
    });

    testWidgets('clôture : le suivi s’arrête', (tester) async {
      await openLive(tester);
      live.last
        ..emit(const LiveReady())
        ..emit(const LiveStatus('completed'));
      await tester.pumpAndSettle();
      expect(find.text('Le suivi en direct est terminé.'), findsOneWidget);
    });

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('golden trajet en cours ${mode.name}', (tester) async {
        await openLive(tester, mode: mode);
        live.last
          ..emit(const LiveReady())
          ..emit(LivePosition(userId: 'driver-1', lat: 45.885, lon: 6.135, at: now))
          ..emit(LiveEta(userId: me, eta: now.add(const Duration(minutes: 4))));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/live_${mode.name}.png'),
        );
      });
    }
  });

  testWidgets('golden écran de départ (en cours)', (tester) async {
    await backend.start('ride-2');
    await openDeparture(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/departure_light.png'));
  });

  Future<void> tapTopup(WidgetTester tester) async {
    final button = find.textContaining('Recharger');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  group('portefeuille', () {
    Future<void> openWallet(WidgetTester tester) async {
      await launch(tester);
      await tester.tap(find.byTooltip('Mon profil'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Portefeuille');
    }

    testWidgets('recharger : solde et historique à jour', (tester) async {
      await openWallet(tester);
      expect(find.text('Ton portefeuille'), findsOneWidget);
      expect(find.text('Aucune opération pour l\'instant.'), findsOneWidget);
      await tapText(
        tester,
        find.textContaining('Recharger').evaluate().isEmpty
            ? ''
            : (find.textContaining('Recharger').evaluate().first.widget as Text).data!,
      );
      expect(find.text('Portefeuille rechargé.'), findsOneWidget);
      expect(find.text('Recharge'), findsOneWidget);
      expect(backend.balanceCents, 1000);
    });

    testWidgets('réseau coupé : même clé réessayée ; refus : nouvelle clé', (tester) async {
      await openWallet(tester);
      // Réseau coupé : l'issue est inconnue, la même clé est réutilisée au prochain essai.
      backend.failNext = const ApiException('network_error', '');
      await tapTopup(tester);
      await tapTopup(tester);
      await tester.pump(const Duration(seconds: 5)); // le message disparaît
      await tester.pumpAndSettle();
      // Refus définitif : la clé est renouvelée, la recharge suivante est nouvelle.
      backend.failNext = const ApiException('topup_failed', '', statusCode: 402);
      await tapTopup(tester);
      expect(find.text('La recharge a été refusée.'), findsOneWidget);
      await tapTopup(tester);
      expect(backend.topupKeys, hasLength(2));
      expect(backend.balanceCents, 2000);
      expect(backend.topupKeys.length, 2);
    });

    testWidgets('retirer vers un IBAN : erreurs claires, puis solde et historique à jour', (
      tester,
    ) async {
      Future<void> tapSubmit() async {
        // Montant formaté avec une espace insécable avant l'euro.
        await tester.tap(find.textContaining('Retirer 12,50'));
        await tester.pumpAndSettle();
      }

      backend.balanceCents = 2500;
      await openWallet(tester);
      await tapText(tester, 'Retirer vers mon compte');
      expect(find.text('Retirer ton solde'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), '12,5');
      await tester.enterText(find.byType(TextField).at(1), 'DE89 3704 0044 0532 0130 00');
      await tester.enterText(find.byType(TextField).at(2), 'Léa Martin');
      await tester.pumpAndSettle();
      await tapSubmit();
      expect(find.textContaining('Cet IBAN n\'est pas valide'), findsOneWidget);
      expect(backend.payouts, isEmpty);

      await tester.enterText(find.byType(TextField).at(1), 'fr76 3000 6000 0112 3456 7890 189');
      await tester.pumpAndSettle();
      await tapSubmit();
      expect(backend.payouts.single.request.amountCents, 1250);
      expect(backend.payouts.single.request.iban, 'FR7630006000011234567890189');
      expect(find.text('Ton portefeuille'), findsOneWidget);
      expect(find.text('Retrait'), findsOneWidget);
      expect(backend.balanceCents, 1250);
    });

    testWidgets('golden retrait', (tester) async {
      backend.balanceCents = 2500;
      await openWallet(tester);
      await tapText(tester, 'Retirer vers mon compte');
      await tester.enterText(find.byType(TextField).at(0), '25');
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/payout_light.png'));
    });

    testWidgets('golden portefeuille', (tester) async {
      backend.balanceCents = 1240;
      await openWallet(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/wallet_light.png'));
    });
  });
}
