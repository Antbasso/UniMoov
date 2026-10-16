import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
    unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push(location));
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
      expect(find.text('Annuler ce trajet ?'), findsOneWidget);
      expect(
        find.text('Le départ approche : ton score de fiabilité baisse davantage.'),
        findsOneWidget,
      );
      expect(find.textContaining('ta place est proposée à quelqu\'un d\'autre'), findsOneWidget);
      await tapText(tester, 'Confirmer l\'annulation');
      expect(backend.cancelled, ['ride-1']);
      expect(find.text('Trajet annulé.'), findsOneWidget);
      expect(find.text('Arrêts'), findsNothing);
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
      expect(find.textContaining('Départ imminent'), findsOneWidget);
      expect(
        find.text('Tes passagers sont prévenus et on leur cherche une autre voiture.'),
        findsOneWidget,
      );
    });
  });

  group('trajet terminé', () {
    testWidgets('noter le conducteur une fois, de 1 à 5', (tester) async {
      completed();
      await openRide(tester);
      expect(find.text('Noter le trajet'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('4 sur 5 pour Nathan'));
      await tester.tap(find.byTooltip('4 sur 5 pour Nathan'));
      await tester.pumpAndSettle();
      expect(backend.given, {'ride-1|driver-1': 4});
      expect(find.text('Ta note : 4 sur 5'), findsOneWidget);
      expect(find.byTooltip('5 sur 5 pour Nathan'), findsNothing);
    });

    testWidgets(
      'compté absent : explication, pas de note, litige maintenu puis transmis à l’équipe',
      (tester) async {
        completed(myStatus: 'absent');
        await openRide(tester);
        expect(
          find.text('Ta présence n\'a pas été validée : ce trajet compte comme une absence.'),
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
        expect(find.text('À l\'équipe'), findsOneWidget);
        expect(find.text('Demande transmise à l\'équipe.'), findsOneWidget);
        expect(find.text('Je ne suis pas d\'accord'), findsNothing);
      },
    );

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
      // Seule l'entrée récente est encore contestable.
      expect(find.text('Contester'), findsOneWidget);

      await tapText(tester, 'Contester');
      await tapText(tester, 'Envoyer');
      expect(backend.disputesById['ride-9']!.single.reason, DisputeReason.cancellationPenalty);
      expect(find.textContaining('Les horodatages confirment'), findsOneWidget);
    });

    testWidgets('aucune pénalité : état vide', (tester) async {
      backend.reliabilityState = reliabilityFixture(events: const []);
      await go(tester, AppRoutes.reliability);
      expect(find.text('Aucune annulation ni absence ces derniers mois.'), findsOneWidget);
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
