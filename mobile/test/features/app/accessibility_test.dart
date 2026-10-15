import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/core/storage/token_storage.dart';
import 'package:unimoov/features/auth/domain/auth_tokens.dart';
import 'package:unimoov/features/profile/domain/me.dart';

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
    await tapText(tester, 'Terminer');
    await tester.tap(find.byTooltip('Mon profil'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
