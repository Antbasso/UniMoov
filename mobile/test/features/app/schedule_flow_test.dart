import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/core/storage/token_storage.dart';
import 'package:unimoov/features/auth/domain/auth_tokens.dart';
import 'package:unimoov/features/profile/domain/me.dart';

import '../../support/app_harness.dart';
import '../../support/fake_backend.dart';

void main() {
  late FakeBackend backend;
  late MemoryTokenStorage storage;

  setUp(() {
    backend = FakeBackend()
      ..seedAccount(
        'lea@etu.univ-smb.fr',
        steps: {
          OnboardingStep.profile: StepStatus.done,
          OnboardingStep.vehicle: StepStatus.done,
          OnboardingStep.preferences: StepStatus.done,
        },
        withHome: true,
      )
      ..resumeSessionFor('lea@etu.univ-smb.fr');
    storage = MemoryTokenStorage()..tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
  });

  testWidgets('onboarding : lien ICS, consentement exigé puis connexion', (tester) async {
    await launchApp(tester, backend: backend, storage: storage);
    expect(find.text('Étape 4 sur 4'), findsOneWidget);
    await tapText(tester, 'Coller mon lien d\'agenda (ICS)');
    await tester.enterText(fieldLabeled('Lien ICS'), FakeBackend.validIcs);
    await tapText(tester, 'Continuer');
    expect(find.text('Coche la case pour autoriser la lecture de ton agenda.'), findsOneWidget);
    expect(backend.connection, isNull);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tapText(tester, 'Continuer');
    expect(backend.connection, isNotNull);
    expect(find.text('Ta semaine'), findsOneWidget);
  });

  testWidgets('onboarding : lien illisible, message clair', (tester) async {
    await launchApp(tester, backend: backend, storage: storage);
    await tapText(tester, 'Coller mon lien d\'agenda (ICS)');
    await tester.enterText(fieldLabeled('Lien ICS'), 'https://autre.example/cal.ics');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tapText(tester, 'Continuer');
    expect(find.textContaining('Impossible de lire ton agenda'), findsOneWidget);
  });

  testWidgets('onboarding : horaires saisis à la main (lundi à vendredi par défaut)', (
    tester,
  ) async {
    await launchApp(tester, backend: backend, storage: storage);
    await tapText(tester, 'Saisir mes horaires');
    expect(find.text('Début 08:00'), findsNWidgets(5));
    await tapText(tester, 'Continuer');
    expect(backend.manualDays.map((d) => d.weekday), [1, 2, 3, 4, 5]);
    expect(find.text('Ta semaine'), findsOneWidget);
  });

  testWidgets('profil : agenda connecté, mise à jour et déconnexion', (tester) async {
    backend.seedAccount(
      'lea@etu.univ-smb.fr',
      steps: {for (final s in OnboardingStep.values) s: StepStatus.done},
      withHome: true,
    );
    await backend.connectIcs(FakeBackend.validIcs);
    await launchApp(tester, backend: backend, storage: storage);
    await tester.tap(find.byTooltip('Mon profil'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Emploi du temps');
    expect(find.textContaining('Agenda connecté'), findsOneWidget);
    await tapText(tester, 'Mettre à jour');
    expect(find.text('Emploi du temps mis à jour.'), findsOneWidget);
    await tapText(tester, 'Déconnecter l\'agenda');
    expect(backend.connection, isNull);
    expect(find.text('Aucun emploi du temps.'), findsOneWidget);
  });
}
