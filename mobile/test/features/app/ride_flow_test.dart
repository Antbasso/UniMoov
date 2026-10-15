import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/core/api/api_client.dart';
import 'package:unimoov/core/storage/token_storage.dart';
import 'package:unimoov/features/auth/domain/auth_tokens.dart';

import '../../support/app_harness.dart';
import '../../support/fake_backend.dart';

void main() {
  late FakeBackend backend;
  late MemoryTokenStorage storage;

  setUp(() {
    backend = rideBackend();
    storage = MemoryTokenStorage()..tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
  });

  Future<void> openRide(WidgetTester tester, {int index = 0}) async {
    await launchApp(tester, backend: backend, storage: storage);
    await tapText(tester, 'Voir', index: index);
    await tapText(tester, 'Voir la carte');
  }

  testWidgets('passagère : carte, arrêts dans l’ordre, noms débloqués, prix estimé', (
    tester,
  ) async {
    await openRide(tester);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Arrêts'), findsOneWidget);
    expect(find.text('Nathan Petit'), findsOneWidget); // conducteur : nom complet
    expect(find.text('Toi'), findsOneWidget);
    expect(find.text('Hugo'), findsOneWidget); // autre passager : prénom seulement
    expect(find.text("Campus d'Annecy (USMB)"), findsOneWidget);
    expect(find.text('Tu paies'), findsOneWidget);
    expect(find.textContaining('0,76'), findsOneWidget);
    expect(find.textContaining('partagés entre 3 personnes'), findsOneWidget);
    expect(find.textContaining('Vers '), findsNWidgets(4));
    expect(find.text('Ajouter des passagers'), findsNothing);
  });

  testWidgets('point de rendez-vous : choisir sur la carte, puis revenir à l’adresse', (
    tester,
  ) async {
    await openRide(tester);
    await tapText(tester, 'Choisir un point de rendez-vous');
    expect(find.text('Point de rendez-vous'), findsOneWidget);
    await tester.tap(find.byType(FlutterMap));
    await tester.pumpAndSettle();
    await tester.enterText(fieldLabeled('Nom du point'), 'Arrêt Mairie');
    await tester.pump();
    await tapText(tester, 'Enregistrer ce point');

    expect(find.text('Point de rendez-vous enregistré.'), findsOneWidget);
    expect(find.text('Arrêt Mairie'), findsOneWidget);
    expect(find.text('Point de rendez-vous'), findsOneWidget); // puce sur l'arrêt
    // Le message de confirmation disparaît avant l'action suivante.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tapText(tester, 'Changer de point de rendez-vous');
    await tapText(tester, 'Revenir à mon adresse');
    expect(find.text('Arrêt Mairie'), findsNothing);
    expect(find.text(FakeBackend.knownAddress), findsOneWidget);
  });

  testWidgets('point de rendez-vous trop loin : message du serveur', (tester) async {
    await openRide(tester);
    await tapText(tester, 'Choisir un point de rendez-vous');
    await tester.enterText(fieldLabeled('Nom du point'), 'Gare');
    await tester.pump();
    backend.failNext = const ApiException('meeting_point_too_far', '', statusCode: 422);
    await tapText(tester, 'Enregistrer ce point');
    expect(find.text('Choisis un point plus proche de chez toi.'), findsOneWidget);
  });

  testWidgets('conducteur : ajouter un passager écarté, avec le prix simulé', (tester) async {
    await openRide(tester, index: 1);
    expect(find.text('Tu reçois'), findsOneWidget);
    expect(find.textContaining('1,12'), findsOneWidget);
    expect(find.text('Inès Robert'), findsOneWidget);
    await tapText(tester, 'Ajouter des passagers');

    expect(find.textContaining('chaque passager paie 0,76'), findsOneWidget);
    expect(find.text('Théo'), findsOneWidget);
    expect(find.text('Au-delà de ton détour max'), findsOneWidget);
    expect(find.textContaining(RegExp(r'0,68.€ par passager au lieu de 0,76')), findsOneWidget);
    await tapText(tester, 'Proposer une place');

    expect(backend.invited, ['theo']);
    expect(find.text('Proposition envoyée à Théo.'), findsOneWidget);
    expect(find.text('Personne d\'autre ne cherche de trajet à cette heure-là.'), findsOneWidget);
  });

  testWidgets('la proposition du conducteur ouvre aussi les suggestions', (tester) async {
    await launchApp(tester, backend: backend, storage: storage);
    await tapText(tester, 'Voir', index: 1);
    await tapText(tester, 'Ajouter des passagers');
    await tapText(tester, 'Proposer une place');
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    expect(find.text('Théo'), findsOneWidget); // ajouté à la proposition
  });

  testWidgets('erreur au chargement du trajet, puis réessayer', (tester) async {
    await launchApp(tester, backend: backend, storage: storage);
    await tapText(tester, 'Voir', index: 0);
    backend.failNext = const ApiException('network_error', '');
    await tapText(tester, 'Voir la carte');
    expect(find.text('Réessayer'), findsOneWidget);
    await tapText(tester, 'Réessayer');
    expect(find.text('Arrêts'), findsOneWidget);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('golden trajet confirmé ${mode.name}', (tester) async {
      await launchApp(tester, backend: backend, storage: storage, themeMode: mode);
      await tapText(tester, 'Voir', index: 0);
      await tapText(tester, 'Voir la carte');
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/ride_${mode.name}.png'),
      );
    });
  }

  testWidgets('golden suggestions conducteur', (tester) async {
    await openRide(tester, index: 1);
    await tapText(tester, 'Ajouter des passagers');
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/suggestions_light.png'));
  });
}
