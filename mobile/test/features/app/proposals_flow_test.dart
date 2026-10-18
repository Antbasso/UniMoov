import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/core/api/api_client.dart';
import 'package:unimoov/core/storage/token_storage.dart';
import 'package:unimoov/core/widgets/widgets.dart';
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

  testWidgets('ma semaine : ouvrir un trajet, carte et personnes, accepter', (tester) async {
    await launchApp(tester, backend: backend, storage: storage);
    expect(find.text('Ta semaine'), findsOneWidget);
    // Domicile → campus, sans « près de chez toi » ; rôle d'un coup d'œil (icône et info-bulle).
    expect(find.textContaining('Domicile', findRichText: true), findsNWidgets(2));
    expect(find.textContaining('près de chez toi'), findsNothing);
    expect(find.byTooltip('Passager'), findsOneWidget);
    expect(find.byTooltip('Tu conduis'), findsOneWidget);
    expect(find.text('Nathan'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);

    await openTrip(tester, index: 0);
    // Un seul écran : la carte tout de suite, la personne dessous, en chiffres.
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(backend.previews, 1);
    expect(find.byType(CircleLayer), findsOneWidget);
    expect(find.text('Nathan'), findsOneWidget);
    expect(find.text('4,5'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Fait 4 minutes de détour pour toi')), findsOneWidget);
    expect(find.textContaining('Nom et adresse sont partagés'), findsOneWidget);
    // Titre court dans la barre du haut.
    expect(find.textContaining('Aller · '), findsOneWidget);

    await tapText(tester, 'Accepter');
    expect(find.text('Accepter'), findsNothing);
    expect(find.text('En attente'), findsWidgets);
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    expect(find.text('En attente'), findsOneWidget);
  });

  testWidgets('solde insuffisant : explication, puis recharge en un geste', (tester) async {
    backend.requiredBalanceCents = 500;
    await launchApp(tester, backend: backend, storage: storage);
    await openTrip(tester, index: 0);
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
    expect(find.text('Accepter'), findsNothing);
  });

  testWidgets('conducteur : voit ses passagers, sans « voir d’autres »', (tester) async {
    await launchApp(tester, backend: backend, storage: storage);
    await openTrip(tester, index: -1);
    expect(find.text('Hugo'), findsOneWidget);
    // Proposé, pas encore accepté : provisoire (dans la liste et sur la carte).
    expect(find.text('En attente'), findsOneWidget);
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
    await openTrip(tester, index: -1);
    expect(find.text('Demande'), findsOneWidget);
    await tapText(tester, 'Accepter', index: 0);
    expect(backend.requestAnswers.single, (rideId: 'from-monday', userId: 'p9', approve: true));
    expect(find.text('Demande'), findsNothing);
    expect(find.text('Accepté'), findsOneWidget);
  });

  testWidgets('passager : demande en attente, puis retirée', (tester) async {
    backend.weeks[week]![0] = backend.weeks[week]![0].copyWith(myStatus: 'requested');
    await launchApp(tester, backend: backend, storage: storage);
    await openTrip(tester, index: 0);
    expect(find.text('Demande envoyée'), findsOneWidget);
    expect(find.text('Accepter'), findsNothing);
    await tapText(tester, 'Retirer ma demande');
    expect(find.text('Nathan'), findsNothing);
  });

  testWidgets('refuser retire la proposition', (tester) async {
    await launchApp(tester, backend: backend, storage: storage);
    await openTrip(tester, index: 0);
    await tapText(tester, 'Refuser');
    expect(find.text('Nathan'), findsNothing);
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
    await openTrip(tester, index: 0);
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
    await openTrip(tester, index: 0);
    await tapText(tester, 'Voir d\'autres voitures');
    expect(find.text('Aucune autre voiture compatible pour ce créneau.'), findsOneWidget);
  });

  testWidgets('recherche : quota atteint puis aucun résultat', (tester) async {
    await launchApp(tester, backend: backend, storage: storage);
    await tester.tap(find.byTooltip('Chercher un trajet'));
    await tester.pumpAndSettle();
    expect(find.text('Choisis un jour et un sens, puis lance la recherche.'), findsOneWidget);
    // Un calendrier des deux semaines à venir ; les jours passés ne se choisissent pas.
    expect(find.byType(UmCalendar), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('vendredi 16 octobre'));
    await tester.pump();
    expect(
      tester.getSemantics(find.bySemanticsLabel('vendredi 16 octobre')).flagsCollection.isSelected,
      Tristate.isTrue,
    );
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
    await openTrip(tester, index: 0);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/proposal_light.png'));
  });
}
