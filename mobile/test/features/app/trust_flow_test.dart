import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:unimoov/core/api/api_client.dart';
import 'package:unimoov/core/router/redirect.dart';
import 'package:unimoov/core/storage/token_storage.dart';
import 'package:unimoov/features/auth/domain/auth_tokens.dart';
import 'package:unimoov/features/trust/domain/trust.dart';

import '../../support/app_harness.dart';
import '../../support/fake_backend.dart';
import 'accessibility_test.dart' show expectAccessible;

/// M5 : annulation avec pénalité annoncée, notation, litige, signalement, fiabilité.
void main() {
  late FakeBackend backend;
  late MemoryTokenStorage storage;

  setUp(() {
    backend = rideBackend();
    storage = MemoryTokenStorage()..tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
  });

  Future<void> openRide(
    WidgetTester tester, {
    int index = 0,
    ThemeMode mode = ThemeMode.light,
  }) async {
    await launchApp(tester, backend: backend, storage: storage, themeMode: mode);
    await tapText(tester, 'Voir', index: index);
    await tapText(tester, 'Voir la carte');
  }

  Future<void> go(WidgetTester tester, String location, {ThemeMode mode = ThemeMode.light}) async {
    await launchApp(tester, backend: backend, storage: storage, themeMode: mode);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
    await tester.pumpAndSettle();
  }

  void completed({String myStatus = 'accepted'}) {
    backend.rides['ride-1'] = rideFixture(status: 'completed', myStatus: myStatus);
    backend.ratingsById['ride-1'] = const RideRatings(
      open: true,
      people: [RatingTarget(userId: 'driver-1', firstName: 'Nathan', isDriver: true)],
    );
  }

  group('annulation', () {
    testWidgets('passagère : pénalité annoncée, confirmée, retour à l’accueil', (tester) async {
      await openRide(tester);
      await tapText(tester, 'Annuler ma place');
      expect(find.text('Annuler ta place ?'), findsOneWidget);
      expect(find.text('Le départ approche\u00a0: ton score baisse davantage.'), findsOneWidget);
      expect(find.textContaining('ta place est proposée à quelqu\'un d\'autre'), findsOneWidget);
      // Bouton de la feuille (le même libellé reste visible sous la feuille).
      await tester.tap(find.text('Annuler ma place').last);
      await tester.pumpAndSettle();
      expect(backend.cancelled, ['ride-1']);
      expect(find.text('Ta place est annulée.'), findsOneWidget);
      expect(find.text('Arrêts'), findsNothing);
    });

    testWidgets('seuil franchi pendant la confirmation : le palier appliqué est annoncé', (
      tester,
    ) async {
      backend
        ..cancelTier = CancelTier.early
        ..appliedTier = CancelTier.medium;
      await openRide(tester);
      await tapText(tester, 'Annuler ma place');
      await tester.tap(find.text('Annuler ma place').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Ta place est annulée. Le départ approche'), findsOneWidget);
    });

    testWidgets('garder son trajet : rien n’est annulé', (tester) async {
      await openRide(tester);
      await tapText(tester, 'Annuler ma place');
      await tapText(tester, 'Garder mon trajet');
      expect(backend.cancelled, isEmpty);
      expect(find.text('Arrêts'), findsOneWidget);
    });

    testWidgets('conducteur au dernier moment : pénalité forte, passagers relancés', (
      tester,
    ) async {
      backend.cancelTier = CancelTier.late;
      await openRide(tester, index: 1);
      await tapText(tester, 'Annuler le trajet');
      expect(find.text('Annuler ce trajet ?'), findsOneWidget);
      expect(find.text('Départ imminent\u00a0: ton score baisse nettement.'), findsOneWidget);
      expect(
        find.text('Tes passagers sont prévenus et on leur cherche une autre voiture.'),
        findsOneWidget,
      );
    });
  });

  group('trajet terminé', () {
    testWidgets('noter le conducteur une fois : choisir, corriger, puis envoyer', (tester) async {
      completed();
      await openRide(tester);
      expect(find.text('Noter le trajet'), findsOneWidget);
      Future<void> star(int n) async {
        await tester.ensureVisible(find.byTooltip('$n sur 5 pour Nathan'));
        await tester.tap(find.byTooltip('$n sur 5 pour Nathan'));
        await tester.pumpAndSettle();
      }

      await star(2); // appui raté : rien n'est encore envoyé
      expect(backend.given, isEmpty);
      await star(4);
      await tapText(tester, 'Envoyer ma note (4 sur 5)');
      expect(backend.given, {'ride-1|driver-1': 4});
      expect(find.text('Ta note\u00a0: 4 sur 5'), findsOneWidget);
      expect(find.byTooltip('5 sur 5 pour Nathan'), findsNothing);
    });

    testWidgets(
      'compté absent : explication, pas de note, litige maintenu puis transmis à l’équipe',
      (tester) async {
        completed(myStatus: 'absent');
        await openRide(tester);
        expect(
          find.text('Ta présence n\'a pas été validée\u00a0: ce trajet compte comme une absence.'),
          findsOneWidget,
        );
        expect(find.text('Noter le trajet'), findsNothing);

        await tapText(tester, 'Un problème sur ce trajet ?');
        await tapText(tester, 'Envoyer'); // motif « absence » déjà choisi
        expect(find.text('Décision maintenue'), findsOneWidget);
        expect(find.textContaining('Aucune validation de présence'), findsOneWidget);
        // Ce motif est traité : il ne se propose plus.
        expect(find.text('Mon absence est une erreur'), findsOneWidget); // titre de la demande

        await tapText(tester, 'Je ne suis pas d\'accord');
        await tester.enterText(
          fieldLabeled('Dis-nous pourquoi (facultatif)'),
          'J’étais au rendez-vous.',
        );
        await tapText(tester, 'Envoyer à l\'équipe');
        expect(find.text('En cours d\'examen'), findsOneWidget);
        expect(find.text('Demande transmise à l\'équipe.'), findsOneWidget);
        expect(find.text('Je ne suis pas d\'accord'), findsNothing);
      },
    );

    testWidgets('notes indisponibles : message et réessai', (tester) async {
      completed();
      backend.failNextRatings = const ApiException('network_error', '');
      await openRide(tester);
      await tester.ensureVisible(find.text('Réessayer'));
      await tapText(tester, 'Réessayer');
      expect(find.byTooltip('4 sur 5 pour Nathan'), findsOneWidget);
    });

    testWidgets('signaler une personne du trajet, avec un motif', (tester) async {
      completed();
      await openRide(tester);
      await tapText(tester, 'Signaler une personne');
      expect(find.text('Envoyer le signalement'), findsOneWidget);
      // Le nom figure aussi dans les arrêts, sous la feuille.
      await tester.tap(find.text('Nathan Petit').last);
      await tester.pumpAndSettle();
      await tapText(tester, 'Conduite dangereuse');
      await tapText(tester, 'Envoyer le signalement');
      expect(backend.reports.single.userId, 'driver-1');
      expect(backend.reports.single.reason, ReportReason.dangerousDriving);
      expect(find.text('Signalement envoyé.'), findsOneWidget);
    });
  });

  group('fiabilité', () {
    testWidgets('score, composantes, pénalité contestée sur les horodatages', (tester) async {
      await go(tester, AppRoutes.reliability);
      expect(find.text('3,7 sur 5'), findsOneWidget);
      expect(find.text('12 trajets menés à bien'), findsOneWidget);
      expect(find.text('9 notes, moyenne 4,6 sur 5'), findsOneWidget);
      expect(find.text('Annulation au dernier moment'), findsOneWidget);
      expect(find.text('Absence au rendez-vous'), findsOneWidget);
      // Seule l'entrée récente est encore contestable ; l'autre le dit.
      expect(find.text('Contester'), findsOneWidget);
      expect(find.text('Délai de contestation dépassé.'), findsOneWidget);

      await tapText(tester, 'Contester');
      await tapText(tester, 'Envoyer');
      expect(backend.disputesById['ride-9']!.single.reason, DisputeReason.cancellationPenalty);
      expect(find.textContaining('Les horodatages confirment'), findsOneWidget);
    });

    testWidgets('aucune pénalité : état vide', (tester) async {
      backend.reliabilityState = reliabilityFixture(events: const []);
      await go(tester, AppRoutes.reliability);
      expect(find.text('Aucune annulation ni absence sur les 180 derniers jours.'), findsOneWidget);
    });

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('accessibilité ${mode.name} : fiabilité, litige, notation', (tester) async {
        final handle = tester.ensureSemantics();
        await go(tester, AppRoutes.reliability, mode: mode);
        await expectAccessible(tester);
        await tapText(tester, 'Contester');
        await expectAccessible(tester);
        completed();
        await openRide(tester, mode: mode);
        await tester.ensureVisible(find.text('Noter le trajet'));
        await tester.pumpAndSettle();
        await expectAccessible(tester);
        handle.dispose();
      });
    }

    testWidgets('golden fiabilité', (tester) async {
      await go(tester, AppRoutes.reliability);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/reliability_light.png'),
      );
    });

    testWidgets('golden litige', (tester) async {
      backend.disputesById['ride-1'] = [
        const Dispute(
          id: 'd-1',
          reason: DisputeReason.markedAbsent,
          level: 1,
          decision: DisputeDecision.upheld,
          explanation: 'no_presence_evidence',
        ),
      ];
      await go(tester, AppRoutes.dispute('ride-1'));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/dispute_light.png'));
    });
  });
}
