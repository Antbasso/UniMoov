import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:unimoov/core/api/api_client.dart';
import 'package:unimoov/core/router/redirect.dart';
import 'package:unimoov/core/storage/token_storage.dart';
import 'package:unimoov/features/auth/domain/auth_tokens.dart';

import '../../support/app_harness.dart';
import '../../support/chat_fakes.dart';
import '../../support/fake_backend.dart';
import 'accessibility_test.dart' show expectAccessible;

/// M7 : droits RGPD depuis le profil (export, suppression) et notifications bloquées.
void main() {
  late FakeBackend backend;
  late MemoryTokenStorage storage;

  setUp(() {
    backend = rideBackend();
    storage = MemoryTokenStorage()..tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
  });

  Future<void> open(
    WidgetTester tester,
    String location, {
    ThemeMode mode = ThemeMode.light,
    FakePushService? push,
    FakeExportSharer? sharer,
  }) async {
    await launchApp(
      tester,
      backend: backend,
      storage: storage,
      themeMode: mode,
      push: push,
      sharer: sharer,
    );
    unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push(location));
    await tester.pumpAndSettle();
  }

  testWidgets('profil : télécharger mes données ouvre la feuille de partage avec le fichier', (
    tester,
  ) async {
    final sharer = FakeExportSharer();
    await open(tester, AppRoutes.profile, sharer: sharer);
    expect(find.text('Mes données'), findsOneWidget);
    await tapText(tester, 'Télécharger mes données');
    expect(sharer.shared.single.fileName, 'uni-moov-mes-donnees.json');
    expect(sharer.shared.single.content, contains('lea@etu.univ-smb.fr'));
  });

  testWidgets('export impossible hors ligne : message, rien de partagé', (tester) async {
    final sharer = FakeExportSharer();
    await open(tester, AppRoutes.profile, sharer: sharer);
    backend.failNext = const ApiException('network_error', '');
    await tapText(tester, 'Télécharger mes données');
    expect(sharer.shared, isEmpty);
    expect(find.textContaining('Connexion impossible'), findsOneWidget);
  });

  testWidgets('suppression : mot de passe exigé, puis retour à l’accueil', (tester) async {
    await open(tester, AppRoutes.profile);
    await tapText(tester, 'Supprimer mon compte');
    expect(find.text('Supprimer ton compte'), findsOneWidget);
    expect(find.textContaining('Gardés sans ton nom'), findsOneWidget);

    // Sans mot de passe, le bouton reste inactif.
    final confirm = find.widgetWithText(TextButton, 'Supprimer définitivement');
    expect(tester.widget<TextButton>(confirm).onPressed, isNull);

    await tester.enterText(fieldLabeled('Ton mot de passe, pour confirmer'), 'pas-le-bon');
    await tester.pump();
    await tapText(tester, 'Supprimer définitivement');
    expect(find.text('Mot de passe incorrect.'), findsOneWidget);
    expect(backend.deletedAccounts, isEmpty);

    await tester.enterText(fieldLabeled('Ton mot de passe, pour confirmer'), 'motdepasse-solide');
    await tester.pump();
    await tapText(tester, 'Supprimer définitivement');
    expect(backend.deletedAccounts, ['lea@etu.univ-smb.fr']);
    expect(storage.tokens, isNull);
    expect(find.text('Ton compte est supprimé.'), findsOneWidget);
    expect(find.text('Ton emploi du temps organise aussi tes trajets.'), findsOneWidget);
  });

  testWidgets('portefeuille non vide : refus expliqué, compte gardé', (tester) async {
    backend.deleteRefusal = 'wallet_not_empty';
    await open(tester, AppRoutes.deleteAccount);
    await tester.enterText(fieldLabeled('Ton mot de passe, pour confirmer'), 'motdepasse-solide');
    await tester.pump();
    await tapText(tester, 'Supprimer définitivement');
    expect(find.textContaining('Ton portefeuille n\'est pas vide'), findsOneWidget);
    expect(storage.tokens, isNotNull);
  });

  testWidgets('garder mon compte : retour au profil', (tester) async {
    await open(tester, AppRoutes.profile);
    await tapText(tester, 'Supprimer mon compte');
    await tapText(tester, 'Garder mon compte');
    expect(find.text('Mes données'), findsOneWidget);
  });

  testWidgets('notifications bloquées sur le téléphone : encart et accès aux réglages', (
    tester,
  ) async {
    final push = FakePushService()..blocked = true;
    await open(tester, AppRoutes.notificationSettings, push: push);
    expect(find.text('Notifications bloquées'), findsOneWidget);
    await tapText(tester, 'Ouvrir les réglages');
    expect(push.settingsOpened, 1);

    // Réactivées dans les réglages : l'encart disparaît au retour dans l'app.
    push.blocked = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Notifications bloquées'), findsNothing);
  });

  testWidgets('notifications autorisées : pas d’encart', (tester) async {
    await open(tester, AppRoutes.notificationSettings);
    expect(find.text('Notifications bloquées'), findsNothing);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('accessibilité ${mode.name} : suppression, notifications bloquées', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, AppRoutes.deleteAccount, mode: mode);
      await expectAccessible(tester);
      await open(
        tester,
        AppRoutes.notificationSettings,
        mode: mode,
        push: FakePushService()..blocked = true,
      );
      await expectAccessible(tester);
      handle.dispose();
    });
  }

  testWidgets('golden suppression du compte', (tester) async {
    await open(tester, AppRoutes.deleteAccount);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/delete_account_light.png'),
    );
  });
}
