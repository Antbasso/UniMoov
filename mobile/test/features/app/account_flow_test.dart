import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:unimoov/core/api/api_client.dart';
import 'package:unimoov/core/router/redirect.dart';
import 'package:unimoov/core/storage/token_storage.dart';
import 'package:unimoov/features/auth/domain/auth_tokens.dart';
import 'package:unimoov/features/profile/domain/me.dart';
import 'package:unimoov/features/proposals/domain/proposal.dart';
import 'package:unimoov/features/rides/domain/ride.dart';

import '../../support/app_harness.dart';
import '../../support/chat_fakes.dart';
import '../../support/fake_backend.dart';
import '../../support/live_fakes.dart';
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
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
    await tester.pumpAndSettle();
  }

  testWidgets('profil : solde visible, historique des trajets terminés', (tester) async {
    backend.historyEntries = [
      HistoryEntry(
        id: 'ride-1',
        day: DateTime(2026, 10, 12),
        direction: Direction.toCampus,
        time: DateTime(2026, 10, 12, 8),
        isDriver: false,
        myStatus: 'accepted',
        amountCents: 245,
        withNames: const ['Nathan'],
      ),
    ];
    await open(tester, AppRoutes.profile);
    // Le solde se lit directement, sans « Modifier ».
    expect(find.text('Portefeuille'), findsOneWidget);
    expect(find.text('Modifier'), findsNothing);
    await tapText(tester, 'Historique');
    expect(find.textContaining('Lundi 12 octobre'), findsOneWidget);
    expect(find.textContaining('Nathan'), findsOneWidget);
    expect(find.textContaining('2,45'), findsOneWidget);
  });

  testWidgets('profil : photo, « À propos de moi », puis mon profil vu par les autres', (
    tester,
  ) async {
    await open(tester, AppRoutes.profile);
    await tester.tap(find.bySemanticsLabel('Changer ma photo'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Choisir une photo');
    expect(find.text('Photo enregistrée.'), findsOneWidget);
    expect(backend.me.photo, testPng);
    // Le message disparaît avant la suite (il couvrirait le bouton du bas).
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tapText(tester, 'À propos de moi');
    await tester.enterText(fieldLabeled('Formation'), 'BUT Informatique');
    await tester.enterText(fieldLabeled('Année de naissance'), '1900');
    await tester.enterText(fieldLabeled('Ajouter un centre d\'intérêt'), 'Escalade');
    await tester.tap(find.byTooltip('Ajouter un centre d\'intérêt'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Enregistrer');
    expect(find.textContaining('Indique une année, par exemple 2005.'), findsOneWidget);
    await tester.enterText(fieldLabeled('Année de naissance'), '2005');
    await tapText(tester, 'Enregistrer');
    expect(backend.me.studyProgram, 'BUT Informatique');
    expect(backend.me.birthYear, 2005);
    expect(backend.me.interests, ['Escalade']);
    expect(find.textContaining('BUT Informatique · '), findsOneWidget);
  });

  testWidgets('profil : thème et animations réduites ; mon nom ouvre mon profil public', (
    tester,
  ) async {
    await open(tester, AppRoutes.profile);
    expect(find.text('Voir mon profil comme les autres'), findsNothing);
    await tapText(tester, 'Thème');
    await tapText(tester, 'Sombre');
    expect(find.text('Sombre'), findsOneWidget);
    await tester.ensureVisible(find.text('Réduire les animations'));
    await tapText(tester, 'Réduire les animations');
    final reduce = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(reduce.value, isTrue);
    final app = tester.element(find.byType(Scaffold).first);
    expect(MediaQuery.disableAnimationsOf(app), isTrue);

    backend.profiles['id-lea@etu.univ-smb.fr'] = const PublicProfile(
      id: 'id-lea@etu.univ-smb.fr',
      firstName: 'Léa',
      reliabilityScore: 0.8,
      ridesCompleted: 3,
    );
    await tester.scrollUntilVisible(find.textContaining('Léa'), -200);
    await tester.tap(find.textContaining('Léa').first);
    await tester.pumpAndSettle();
    expect(find.text('Léa'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('trajet : toucher le conducteur ouvre son profil, sans nom ni adresse', (
    tester,
  ) async {
    await launchApp(tester, backend: backend, storage: storage);
    await openTrip(tester, index: 0);
    await tester.tap(find.text('Nathan Petit'));
    await tester.pumpAndSettle();
    expect(find.text('Nathan, 20 ans'), findsOneWidget);
    expect(find.text('BUT Génie mécanique'), findsOneWidget);
    expect(find.text('Ski'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.textContaining('Petit'), findsNothing);
  });

  testWidgets('profil : télécharger mes données ouvre la feuille de partage avec le fichier', (
    tester,
  ) async {
    final sharer = FakeExportSharer();
    await open(tester, AppRoutes.profile, sharer: sharer);
    expect(find.text('Exporter mes données'), findsOneWidget);
    await tapText(tester, 'Exporter mes données');
    expect(sharer.shared.single.fileName, 'uni-moov-mes-donnees.json');
    expect(sharer.shared.single.content, contains('lea@etu.univ-smb.fr'));
    expect(find.text('Tes données sont prêtes.'), findsOneWidget);
  });

  testWidgets('export impossible hors ligne : message, rien de partagé', (tester) async {
    final sharer = FakeExportSharer();
    await open(tester, AppRoutes.profile, sharer: sharer);
    backend.failNext = const ApiException('network_error', '');
    await tapText(tester, 'Exporter mes données');
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
    expect(find.textContaining('Mot de passe incorrect. Réessaie.'), findsOneWidget);
    expect(backend.deletedAccounts, isEmpty);

    await tester.enterText(fieldLabeled('Ton mot de passe, pour confirmer'), 'motdepasse-solide');
    await tester.pump();
    await tapText(tester, 'Supprimer définitivement');
    expect(backend.deletedAccounts, ['lea@etu.univ-smb.fr']);
    expect(storage.tokens, isNull);
    expect(find.text('Ton compte est supprimé.'), findsOneWidget);
    expect(find.text('Ton emploi du temps organise aussi tes trajets.'), findsOneWidget);
  });

  testWidgets('portefeuille non vide : bloqué avant le mot de passe, écrire à l’équipe', (
    tester,
  ) async {
    final launcher = FakeNavLauncher();
    backend.balanceCents = 1240;
    await launchApp(tester, backend: backend, storage: storage, launcher: launcher);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(AppRoutes.deleteAccount);
    await tester.pumpAndSettle();
    expect(find.text('Portefeuille à vider d\'abord'), findsOneWidget);
    expect(find.textContaining('12,40'), findsOneWidget);
    expect(fieldLabeled('Ton mot de passe, pour confirmer'), findsNothing);
    await tapText(tester, 'Écrire à l\'équipe');
    expect(launcher.opened.single.scheme, 'mailto');
    // Sans application de mail : l'adresse est donnée.
    launcher.succeed = false;
    await tapText(tester, 'Écrire à l\'équipe');
    expect(find.textContaining('Aucune application de mail'), findsOneWidget);
    expect(backend.deletedAccounts, isEmpty);
  });

  testWidgets('refus du serveur (trajet en cours) : message, compte gardé', (tester) async {
    backend.deleteRefusal = 'ride_in_progress';
    await open(tester, AppRoutes.deleteAccount);
    await tester.enterText(fieldLabeled('Ton mot de passe, pour confirmer'), 'motdepasse-solide');
    await tester.pump();
    await tapText(tester, 'Supprimer définitivement');
    expect(find.text('Termine ton trajet en cours avant de supprimer ton compte.'), findsOneWidget);
    expect(storage.tokens, isNotNull);
  });

  testWidgets('garder mon compte : retour au profil', (tester) async {
    await open(tester, AppRoutes.profile);
    await tapText(tester, 'Supprimer mon compte');
    await tapText(tester, 'Garder mon compte');
    expect(find.text('Exporter mes données'), findsOneWidget);
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

  testWidgets('golden suppression bloquée (sombre)', (tester) async {
    backend.balanceCents = 1240;
    await open(tester, AppRoutes.deleteAccount, mode: ThemeMode.dark);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/delete_account_blocked_dark.png'),
    );
  });

  testWidgets('golden notifications bloquées', (tester) async {
    await open(tester, AppRoutes.notificationSettings, push: FakePushService()..blocked = true);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/notifications_blocked_light.png'),
    );
  });
}
