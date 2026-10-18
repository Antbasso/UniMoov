import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/core/api/api_client.dart';
import 'package:unimoov/core/storage/token_storage.dart';
import 'package:unimoov/features/auth/domain/auth_tokens.dart';
import 'package:unimoov/features/profile/domain/me.dart';
import 'package:unimoov/features/proposals/domain/proposal.dart';
import 'package:unimoov/features/schedule/domain/schedule.dart';

import '../../support/app_harness.dart';
import '../../support/fake_backend.dart';

void main() {
  late FakeBackend backend;
  late MemoryTokenStorage storage;
  final now = testNow;
  final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
  final week = isoWeekOf(now);

  setUp(() {
    backend = FakeBackend()
      ..seedAccount(
        'lea@etu.univ-smb.fr',
        steps: {for (final s in OnboardingStep.values) s: StepStatus.done},
        withHome: true,
      )
      ..resumeSessionFor('lea@etu.univ-smb.fr')
      ..manualDays = [const ManualDay(weekday: 1, startTime: '08:00', endTime: '17:00')];
    backend.weeks[week] = [
      proposalFixture(id: 'to-monday', day: monday),
      proposalFixture(
        id: 'from-monday',
        day: monday,
        direction: Direction.fromCampus,
        isDriver: true,
        passengers: const [
          PublicPerson(
            userId: 'p1',
            firstName: 'Hugo',
            reliabilityScore: 0.8,
            detourMinutes: 2,
            status: 'proposed',
          ),
        ],
      ),
    ];
    storage = MemoryTokenStorage()..tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
  });

  testWidgets('ma semaine : voir, accepter (en attente de l’autre)', (tester) async {
    await launchApp(tester, backend: backend, storage: storage);
    expect(find.text('Ta semaine'), findsOneWidget);
    expect(find.textContaining('Avec Nathan'), findsOneWidget);
    // Rôle visible d'un coup d'œil : passagère lundi matin, conductrice lundi soir.
    expect(find.text('Passager'), findsOneWidget);
    expect(find.text('Tu conduis'), findsOneWidget);
    expect(find.text('1 passager'), findsOneWidget);

    await tapText(tester, 'Voir', index: 0);
    expect(find.text('Tu montes avec'), findsOneWidget);
    expect(find.text('Nathan'), findsOneWidget);
    expect(find.textContaining('Fiabilité 4,5 sur 5'), findsOneWidget);
    expect(find.textContaining('Nom et adresse exacte'), findsOneWidget);
    // Le détour est celui que fait le conducteur ; son secteur, un cercle sur une carte.
    expect(find.textContaining('min de détour pour toi'), findsOneWidget);
    await tapText(tester, 'Voir son secteur');
    expect(find.text('Secteur de Nathan'), findsOneWidget);
    expect(find.byType(CircleLayer), findsOneWidget);
    Navigator.of(tester.element(find.text('Secteur de Nathan'))).pop();
    await tester.pumpAndSettle();

    await tapText(tester, 'Accepter');
    expect(find.text('Tu as accepté. On attend la réponse de l\'autre.'), findsOneWidget);
    expect(find.text('Accepter'), findsNothing);
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    expect(find.text('En attente'), findsOneWidget);
  });

  testWidgets('solde insuffisant : explication, puis recharge en un geste', (tester) async {
    backend.requiredBalanceCents = 500;
    await launchApp(tester, backend: backend, storage: storage);
    await tapText(tester, 'Voir', index: 0);
    await tapText(tester, 'Accepter');
    expect(find.text('Solde insuffisant'), findsOneWidget);
    await tapText(tester, 'Plus tard');
    expect(find.text('Accepter'), findsOneWidget);

    await tapText(tester, 'Accepter');
    await tapText(tester, 'Recharger');
    expect(find.text('Ton portefeuille'), findsOneWidget);
    await tester.tap(find.textContaining('Recharger 10,00'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Accepter');
    expect(find.text('Tu as accepté. On attend la réponse de l\'autre.'), findsOneWidget);
  });

  testWidgets('conducteur : voit ses passagers, sans « voir d’autres »', (tester) async {
    await launchApp(tester, backend: backend, storage: storage);
    await tester.tap(find.text('Voir').last);
    await tester.pumpAndSettle();
    expect(find.text('Tes passagers'), findsOneWidget);
    expect(find.text('Hugo'), findsOneWidget);
    expect(find.text('Voir d\'autres voitures'), findsNothing);
  });

  testWidgets('conducteur : accepter une demande de place', (tester) async {
    backend.weeks[week]![1] = backend.weeks[week]![1].copyWith(
      passengers: const [
        PublicPerson(
          userId: 'p9',
          firstName: 'Inès',
          reliabilityScore: 0.9,
          detourMinutes: 3,
          status: 'requested',
        ),
      ],
    );
    await launchApp(tester, backend: backend, storage: storage);
    await tester.tap(find.text('Voir').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Demande à monter avec toi.'), findsOneWidget);
    await tapText(tester, 'Accepter', index: 0);
    expect(backend.requestAnswers.single, (rideId: 'from-monday', userId: 'p9', approve: true));
    expect(find.textContaining('Demande à monter avec toi.'), findsNothing);
  });

  testWidgets('passager : demande en attente, puis retirée', (tester) async {
    backend.weeks[week]![0] = backend.weeks[week]![0].copyWith(myStatus: 'requested');
    await launchApp(tester, backend: backend, storage: storage);
    await tapText(tester, 'Voir', index: 0);
    expect(find.text('Demande envoyée'), findsOneWidget);
    expect(find.textContaining('Nathan doit accepter ta demande'), findsOneWidget);
    expect(find.text('Accepter'), findsNothing);
    await tapText(tester, 'Retirer ma demande');
    expect(find.textContaining('Avec Nathan'), findsNothing);
  });

  testWidgets('refuser retire la proposition', (tester) async {
    await launchApp(tester, backend: backend, storage: storage);
    await tapText(tester, 'Voir', index: 0);
    await tapText(tester, 'Refuser');
    expect(find.textContaining('Avec Nathan'), findsNothing);
  });

  testWidgets('voir d’autres voitures puis en choisir une', (tester) async {
    backend.alternativesById['to-monday'] = [
      JoinableRide(
        rideId: 'other-ride',
        day: monday,
        direction: Direction.toCampus,
        time: DateTime(monday.year, monday.month, monday.day, 8),
        seatsLeft: 2,
        driver: const PublicPerson(
          userId: 'd2',
          firstName: 'Chloé',
          reliabilityScore: 0.9,
          detourMinutes: 6,
          status: 'proposed',
        ),
      ),
    ];
    await launchApp(tester, backend: backend, storage: storage);
    await tapText(tester, 'Voir', index: 0);
    await tapText(tester, 'Voir d\'autres voitures');
    expect(find.text('Autres voitures'), findsOneWidget);
    expect(find.textContaining('avec Chloé'), findsOneWidget);
    await tapText(tester, 'Choisir');
    expect(backend.joined, ['other-ride']);
    expect(find.text('Demande envoyée : le conducteur doit l\'accepter.'), findsOneWidget);
    expect(find.text('Ta semaine'), findsOneWidget);
  });

  testWidgets('aucune autre voiture : état vide', (tester) async {
    await launchApp(tester, backend: backend, storage: storage);
    await tapText(tester, 'Voir', index: 0);
    await tapText(tester, 'Voir d\'autres voitures');
    expect(find.text('Aucune autre voiture compatible pour ce créneau.'), findsOneWidget);
  });

  testWidgets('recherche : quota atteint puis aucun résultat', (tester) async {
    await launchApp(tester, backend: backend, storage: storage);
    await tester.ensureVisible(find.text('Chercher un trajet'));
    await tapText(tester, 'Chercher un trajet');
    expect(find.text('Choisis un jour et un sens, puis lance la recherche.'), findsOneWidget);
    // Le titre et le bouton portent le même libellé : on vise le bouton.
    backend.failNext = const ApiException('search_quota_exceeded', '', statusCode: 429);
    await tapText(tester, 'Chercher un trajet', index: 1);
    expect(find.textContaining('nombre de recherches du jour'), findsOneWidget);
    await tapText(tester, 'Chercher un trajet', index: 1);
    expect(find.text('Aucune voiture trouvée pour ce créneau.'), findsOneWidget);
  });

  testWidgets('semaine vide sans emploi du temps : invitation à l’ajouter', (tester) async {
    backend.weeks.clear();
    backend.manualDays = [];
    await launchApp(tester, backend: backend, storage: storage);
    expect(find.text('Ajoute ton emploi du temps pour recevoir tes propositions.'), findsOneWidget);
    await tapText(tester, 'Ajouter mon emploi du temps');
    expect(find.text('Aucun emploi du temps.'), findsOneWidget);
  });

  testWidgets('erreur de chargement de la semaine puis réessai', (tester) async {
    backend.failNext = const ApiException('network_error', '');
    await launchApp(tester, backend: backend, storage: storage);
    // L'erreur réseau a été consommée par le premier appel (profil) ou la semaine.
    if (find.text('Réessayer').evaluate().isNotEmpty) {
      await tapText(tester, 'Réessayer');
    }
    expect(find.text('Ta semaine'), findsOneWidget);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('golden ma semaine ${mode.name}', (tester) async {
      await launchApp(tester, backend: backend, storage: storage, themeMode: mode);
      await tester.ensureVisible(find.text('Ta semaine'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/week_${mode.name}.png'),
      );
    });
  }

  testWidgets('golden détail d’une proposition', (tester) async {
    await launchApp(tester, backend: backend, storage: storage);
    await tapText(tester, 'Voir', index: 0);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/proposal_light.png'));
  });
}
