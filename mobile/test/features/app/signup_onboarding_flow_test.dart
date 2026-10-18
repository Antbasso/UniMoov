import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:unimoov/core/api/api_client.dart';
import 'package:unimoov/core/storage/token_storage.dart';
import 'package:unimoov/features/auth/domain/auth_tokens.dart';
import 'package:unimoov/features/profile/domain/me.dart';

import '../../support/app_harness.dart';
import '../../support/fake_backend.dart';

void main() {
  late FakeBackend backend;
  late MemoryTokenStorage storage;

  setUp(() {
    backend = FakeBackend();
    storage = MemoryTokenStorage();
  });

  testWidgets('s’inscrit, avance dans l’onboarding, quitte et reprend au même endroit', (
    tester,
  ) async {
    await launchApp(tester, backend: backend, storage: storage);
    expect(find.text('Ton emploi du temps organise aussi tes trajets.'), findsOneWidget);

    // Inscription : mail → code → identité.
    await tapText(tester, 'Créer mon compte');
    await tester.enterText(fieldLabeled('Mail universitaire'), 'lea.martin@etu.univ-smb.fr');
    await tapText(tester, 'Recevoir mon code');
    expect(find.text('Vérifie ta boîte mail'), findsOneWidget);
    await tester.enterText(fieldLabeled('Code de confirmation'), FakeBackend.code);
    await tapText(tester, 'Continuer');
    await tester.enterText(fieldLabeled('Prénom'), 'Léa');
    await tester.enterText(fieldLabeled('Nom'), 'Martin');
    await tester.enterText(fieldLabeled('Mot de passe'), 'motdepasse-solide');
    await tapText(tester, 'Créer mon compte');

    // Onboarding, étape 1 : adresse enregistrée.
    expect(find.text('Étape 1 sur 4'), findsOneWidget);
    expect(find.text('Où habites-tu ?'), findsOneWidget);
    // Adresse tapée sans choisir : refusée ; on choisit dans les propositions.
    await tester.enterText(fieldLabeled('Adresse'), '12 rue de la paix');
    await tapText(tester, 'Continuer');
    expect(find.textContaining('Choisis une adresse dans la liste proposée.'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(backend.addressQueries, ['12 rue de la paix']);
    await tapText(tester, FakeBackend.knownLabel);
    await tapText(tester, 'Continuer');

    // Étape 2 : passée.
    expect(find.text('Étape 2 sur 4'), findsOneWidget);
    await tapText(tester, 'Passer pour l\'instant');
    expect(find.text('Étape 3 sur 4'), findsOneWidget);

    // L'utilisateur quitte l'app : nouveau lancement, même stockage, même serveur.
    expect(storage.tokens, isNotNull);
    backend.resumeSessionFor('lea.martin@etu.univ-smb.fr');
    await launchApp(tester, backend: backend, storage: storage);
    expect(find.text('Étape 3 sur 4'), findsOneWidget);
    expect(find.text('Quel rôle préfères-tu ?'), findsOneWidget);

    // Fin de l'onboarding puis accueil connecté, hors mode découverte (adresse donnée).
    await tapText(tester, 'Continuer');
    expect(find.text('Ton emploi du temps'), findsOneWidget);
    await tapText(tester, 'Passer pour l\'instant');
    expect(find.text('Salut Léa'), findsOneWidget);
    expect(find.text('Mode découverte'), findsNothing);
    expect(find.text('Ta semaine'), findsOneWidget);
  });

  testWidgets('tout passer laisse l’utilisateur en mode découverte', (tester) async {
    backend.seedAccount('lea@etu.univ-smb.fr');
    backend.resumeSessionFor('lea@etu.univ-smb.fr');
    storage.tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
    await launchApp(tester, backend: backend, storage: storage);
    for (var i = 0; i < 4; i++) {
      await tapText(tester, 'Passer pour l\'instant');
    }
    expect(find.text('Mode découverte'), findsOneWidget);
    await tapText(tester, 'Compléter mon profil');
    expect(find.text('Où habites-tu ?'), findsOneWidget);
    expect(find.text('Passer pour l\'instant'), findsNothing);
  });

  testWidgets('erreurs affichées en clair : domaine refusé, adresse introuvable', (tester) async {
    await launchApp(tester, backend: backend, storage: storage);
    await tapText(tester, 'Créer mon compte');
    await tester.enterText(fieldLabeled('Mail universitaire'), 'lea@gmail.com');
    await tapText(tester, 'Recevoir mon code');
    expect(find.text('Utilise ton adresse mail universitaire (univ-smb.fr).'), findsOneWidget);
  });

  testWidgets('connexion : mauvais mot de passe puis succès', (tester) async {
    backend.seedAccount(
      'lea@etu.univ-smb.fr',
      steps: {for (final s in OnboardingStep.values) s: StepStatus.skipped},
    );
    await launchApp(tester, backend: backend, storage: storage);
    await tapText(tester, 'J\'ai déjà un compte');
    await tester.enterText(fieldLabeled('Mail universitaire'), 'lea@etu.univ-smb.fr');
    await tester.enterText(fieldLabeled('Mot de passe'), 'mauvais');
    await tapText(tester, 'Me connecter');
    expect(find.text('Mail ou mot de passe incorrect.'), findsOneWidget);
    await tester.enterText(fieldLabeled('Mot de passe'), 'motdepasse-solide');
    await tapText(tester, 'Me connecter');
    expect(find.text('Salut Léa'), findsOneWidget);
  });

  testWidgets('profil : déclarer un véhicule, se mettre en pause, se déconnecter', (tester) async {
    backend.seedAccount(
      'lea@etu.univ-smb.fr',
      steps: {for (final s in OnboardingStep.values) s: StepStatus.done},
    );
    backend.resumeSessionFor('lea@etu.univ-smb.fr');
    storage.tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
    await launchApp(tester, backend: backend, storage: storage);

    await tester.tap(find.byTooltip('Mon profil'));
    await tester.pumpAndSettle();
    expect(find.text('Pas de véhicule.'), findsOneWidget);
    expect(find.text('Aucune pause programmée.'), findsOneWidget);

    // Véhicule.
    await tapText(tester, 'Véhicule');
    await tapText(tester, 'Oui, j\'ai une voiture');
    await tester.enterText(fieldLabeled('Consommation (L/100 km)'), '5,8');
    // Modèle et couleur exigés : les passagers reconnaissent la voiture.
    await tapText(tester, 'Enregistrer');
    expect(find.textContaining('Indique le modèle'), findsOneWidget);
    await tester.enterText(fieldLabeled('Modèle'), 'Renault Clio');
    await tapText(tester, 'grise');
    await tapText(tester, 'Enregistrer');
    expect(
      find.text('Renault Clio grise · 5,8 L/100 km · 3 places · détour 10 min'),
      findsOneWidget,
    );

    // Rôle : un « i » explique le mode automatique (alternance entre conducteurs).
    await tapText(tester, 'Rôle');
    await tester.tap(find.byTooltip('Comment marche le mode automatique'));
    await tester.pumpAndSettle();
    expect(find.textContaining('on alterne'), findsOneWidget);
    await tapText(tester, 'Compris');
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();

    // Erreur serveur sur la pause : message, puis succès.
    await tester.tap(find.byTooltip('Mettre en pause'));
    await tester.pumpAndSettle();
    expect(find.text('Choisir les dates'), findsOneWidget);
    await tapText(tester, 'Choisir les dates');
    // Saisie clavier du sélecteur : dates relatives à aujourd'hui (jours passés désactivés).
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    final today = DateTime.now();
    String day(int offset) => DateFormat.yMd('fr').format(today.add(Duration(days: offset)));
    await tester.enterText(find.byType(TextField).at(0), day(1));
    await tester.enterText(find.byType(TextField).at(1), day(5));
    await tapText(tester, 'OK');
    backend.failNext = const ApiException('invalid_pause', '', statusCode: 400);
    await tapText(tester, 'Enregistrer la pause');
    expect(find.textContaining('Vérifie les dates'), findsOneWidget);
    await tapText(tester, 'Enregistrer la pause');
    expect(find.textContaining('Du '), findsOneWidget);

    // Comme dans un agenda : tous les lundis, jusqu'à une date.
    await tester.tap(find.byTooltip('Mettre en pause'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Jours');
    await tapText(tester, 'lun.');
    await tapText(tester, 'Choisir la date de fin');
    await tapText(tester, 'OK');
    expect(find.textContaining('Tous les lundis jusqu'), findsOneWidget);
    await tapText(tester, 'Enregistrer la pause');
    expect(find.textContaining('Tous les lundis jusqu'), findsOneWidget);
    expect((backend.lastPause!.repeat! as RepeatDays).weekdays, {1});

    await tapText(tester, 'Me déconnecter');
    expect(find.text('Créer mon compte'), findsOneWidget);
    expect(storage.tokens, isNull);
  });

  testWidgets('session expirée au lancement : retour à l’accueil public', (tester) async {
    storage.tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
    // Le serveur ne reconnaît plus personne : /me répond 401.
    await launchApp(tester, backend: backend, storage: storage);
    expect(find.text('Impossible de charger ton profil.'), findsOneWidget);
    await tapText(tester, 'Me déconnecter');
    expect(find.text('Créer mon compte'), findsOneWidget);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('golden accueil public ${mode.name}', (tester) async {
      await launchApp(tester, backend: backend, storage: storage, themeMode: mode);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/welcome_${mode.name}.png'),
      );
    });

    testWidgets('golden onboarding véhicule ${mode.name}', (tester) async {
      backend.seedAccount('lea@etu.univ-smb.fr', steps: {OnboardingStep.profile: StepStatus.done});
      backend.resumeSessionFor('lea@etu.univ-smb.fr');
      storage.tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
      await launchApp(tester, backend: backend, storage: storage, themeMode: mode);
      await tapText(tester, 'Oui, j\'ai une voiture');
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/onboarding_vehicle_${mode.name}.png'),
      );
    });

    testWidgets('golden accueil connecté ${mode.name}', (tester) async {
      backend.seedAccount(
        'lea@etu.univ-smb.fr',
        steps: {for (final s in OnboardingStep.values) s: StepStatus.skipped},
      );
      backend.resumeSessionFor('lea@etu.univ-smb.fr');
      storage.tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
      await launchApp(tester, backend: backend, storage: storage, themeMode: mode);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/home_${mode.name}.png'),
      );
    });
  }
}
