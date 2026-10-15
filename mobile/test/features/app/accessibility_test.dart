import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/core/storage/token_storage.dart';
import 'package:unimoov/features/auth/domain/auth_tokens.dart';
import 'package:unimoov/features/profile/domain/me.dart';

import 'package:unimoov/features/proposals/domain/proposal.dart';

import '../../support/app_harness.dart';
import '../../support/fake_backend.dart';

/// Règles WCAG automatisables (zones tactiles 48 px, libellés, contraste 4.5:1) sur chaque
/// écran de M1, en thème clair et sombre.
Future<void> expectAccessible(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

void main() {
  late FakeBackend backend;
  late MemoryTokenStorage storage;

  setUp(() {
    backend = FakeBackend();
    storage = MemoryTokenStorage();
  });

  Future<void> signedIn(WidgetTester tester, ThemeMode mode, {bool onboarded = true}) async {
    backend.seedAccount(
      'lea@etu.univ-smb.fr',
      steps: onboarded ? {for (final s in OnboardingStep.values) s: StepStatus.done} : {},
    );
    backend.resumeSessionFor('lea@etu.univ-smb.fr');
    storage.tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
    await launchApp(tester, backend: backend, storage: storage, themeMode: mode);
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    group('thème ${mode.name}', () {
      testWidgets('accueil public, inscription (3 étapes), connexion', (tester) async {
        final handle = tester.ensureSemantics();
        await launchApp(tester, backend: backend, storage: storage, themeMode: mode);
        await expectAccessible(tester);

        await tapText(tester, 'Créer mon compte');
        await tapText(tester, 'Recevoir mon code'); // erreur de champ visible
        await expectAccessible(tester);
        await tester.enterText(fieldLabeled('Mail universitaire'), 'lea@etu.univ-smb.fr');
        await tapText(tester, 'Recevoir mon code');
        await expectAccessible(tester);
        await tester.enterText(fieldLabeled('Code de confirmation'), FakeBackend.code);
        await tapText(tester, 'Continuer');
        await expectAccessible(tester);

        await launchApp(tester, backend: backend, storage: storage, themeMode: mode);
        await tapText(tester, 'J\'ai déjà un compte');
        await tester.enterText(fieldLabeled('Mail universitaire'), 'x@etu.univ-smb.fr');
        await tester.enterText(fieldLabeled('Mot de passe'), 'faux-mot-de-passe');
        await tapText(tester, 'Me connecter'); // message d'erreur de l'API
        await expectAccessible(tester);
        handle.dispose();
      });

      testWidgets('onboarding : les quatre étapes', (tester) async {
        final handle = tester.ensureSemantics();
        await signedIn(tester, mode, onboarded: false);
        for (var i = 0; i < 3; i++) {
          await expectAccessible(tester);
          await tapText(tester, 'Passer pour l\'instant');
        }
        await expectAccessible(tester);
        handle.dispose();
      });

      testWidgets('accueil connecté, profil, pause', (tester) async {
        final handle = tester.ensureSemantics();
        await signedIn(tester, mode);
        await expectAccessible(tester);
        await tester.tap(find.byTooltip('Mon profil'));
        await tester.pumpAndSettle();
        await expectAccessible(tester);
        await tapText(tester, 'Mettre en pause');
        await expectAccessible(tester);
        handle.dispose();
      });
    });
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('M2 : semaine, détail, autres voitures, recherche (${mode.name})', (tester) async {
      final handle = tester.ensureSemantics();
      final monday = DateTime(2026, 10, 12);
      backend.weeks[isoWeekOf(testNow)] = [proposalFixture(id: 'p1', day: monday)];
      backend.alternativesById['p1'] = [
        JoinableRide(
          rideId: 'r2',
          day: monday,
          direction: Direction.toCampus,
          time: DateTime(2026, 10, 12, 8),
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
      backend.seedAccount(
        'lea@etu.univ-smb.fr',
        steps: {for (final s in OnboardingStep.values) s: StepStatus.done},
        withHome: true,
      );
      backend.resumeSessionFor('lea@etu.univ-smb.fr');
      storage.tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
      await launchApp(tester, backend: backend, storage: storage, themeMode: mode);
      await expectAccessible(tester);
      await tapText(tester, 'Voir');
      await expectAccessible(tester);
      await tapText(tester, 'Voir d\'autres voitures');
      await expectAccessible(tester);
      await launchApp(tester, backend: backend, storage: storage, themeMode: mode);
      await tapText(tester, 'Chercher un trajet');
      await expectAccessible(tester);
      handle.dispose();
    });

    testWidgets('M2 : emploi du temps, lien ICS et horaires (${mode.name})', (tester) async {
      final handle = tester.ensureSemantics();
      backend.seedAccount(
        'lea@etu.univ-smb.fr',
        steps: {
          OnboardingStep.profile: StepStatus.done,
          OnboardingStep.vehicle: StepStatus.done,
          OnboardingStep.preferences: StepStatus.done,
        },
        withHome: true,
      );
      backend.resumeSessionFor('lea@etu.univ-smb.fr');
      storage.tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
      await launchApp(tester, backend: backend, storage: storage, themeMode: mode);
      await expectAccessible(tester);
      await tapText(tester, 'Coller mon lien d\'agenda (ICS)');
      await tapText(tester, 'Continuer'); // erreurs affichées
      await expectAccessible(tester);
      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Saisir mes horaires');
      await expectAccessible(tester);
      handle.dispose();
    });
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('M3 : carte du trajet, point de rendez-vous, suggestions (${mode.name})', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final rides = rideBackend();
      storage.tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
      await launchApp(tester, backend: rides, storage: storage, themeMode: mode);
      await tapText(tester, 'Voir', index: 0);
      await expectAccessible(tester);
      await tapText(tester, 'Voir la carte');
      await expectAccessible(tester);
      await tapText(tester, 'Choisir un point de rendez-vous');
      await expectAccessible(tester);
      await launchApp(tester, backend: rides, storage: storage, themeMode: mode);
      await tapText(tester, 'Voir', index: 1);
      await tapText(tester, 'Ajouter des passagers');
      await expectAccessible(tester);
      handle.dispose();
    });
  }

  testWidgets('M3 à 200 % : aucun débordement', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final rides = rideBackend();
    storage.tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
    await launchApp(tester, backend: rides, storage: storage);
    await tapText(tester, 'Voir', index: 0);
    await tapText(tester, 'Voir la carte');
    expect(tester.takeException(), isNull);
    await tapText(tester, 'Choisir un point de rendez-vous');
    expect(tester.takeException(), isNull);
    await launchApp(tester, backend: rides, storage: storage);
    await tapText(tester, 'Voir', index: 1);
    await tapText(tester, 'Ajouter des passagers');
    expect(tester.takeException(), isNull);
  });

  testWidgets('texte agrandi à 200 % : aucun débordement', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await launchApp(tester, backend: backend, storage: storage);
    await tapText(tester, 'Créer mon compte');
    await launchApp(tester, backend: backend, storage: storage);
    await signedIn(tester, ThemeMode.light, onboarded: false);
    await tapText(tester, 'Passer pour l\'instant');
    await tapText(tester, 'Oui, j\'ai une voiture');
    await tapText(tester, 'Passer pour l\'instant');
    await tapText(tester, 'Passer pour l\'instant');
    await tapText(tester, 'Passer pour l\'instant');
    await tester.tap(find.byTooltip('Mon profil'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Semaine avec propositions et détail, toujours à 200 %.
    backend.weeks[isoWeekOf(testNow)] = [proposalFixture(id: 'p1', day: DateTime(2026, 10, 12))];
    backend.seedAccount(
      'lea@etu.univ-smb.fr',
      steps: {for (final s in OnboardingStep.values) s: StepStatus.done},
      withHome: true,
    );
    await launchApp(tester, backend: backend, storage: storage);
    await tapText(tester, 'Voir');
    expect(tester.takeException(), isNull);
  });
}
