import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:unimoov/core/router/redirect.dart';
import 'package:unimoov/core/storage/token_storage.dart';
import 'package:unimoov/features/auth/domain/auth_tokens.dart';

import '../../support/app_harness.dart';
import '../../support/fake_backend.dart';
import 'accessibility_test.dart' show expectAccessible;

/// Gamification et profil public : niveau en tête du profil, badges, classement anonyme par
/// défaut, profil vu par les autres façon covoiturage, centres d'intérêt à toucher.
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
  }) async {
    await launchApp(tester, backend: backend, storage: storage, themeMode: mode);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'niveau en tête du profil ; badges, impact et classement ; apparaître sous son prénom',
    (tester) async {
      await open(tester, AppRoutes.profile);
      expect(find.text('Habitué'), findsOneWidget);
      expect(find.text('Mon activité'), findsOneWidget); // titres de section
      expect(find.text('Compte et confidentialité'), findsOneWidget);
      await tester.tap(find.text('Habitué'));
      await tester.pumpAndSettle();
      expect(find.text('Mes réussites'), findsOneWidget);
      expect(find.text('Encore 55 points pour devenir Pilier du campus'), findsOneWidget);
      expect(find.text('41 kg'), findsOneWidget);
      expect(find.text('Badges (4/8)'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Apparaître avec mon prénom'), 300);
      expect(find.text('Un étudiant'), findsWidgets);
      expect(backend.me.leaderboardVisible, isFalse);
      await tester.tap(find.text('Apparaître avec mon prénom'));
      await tester.pumpAndSettle();
      expect(backend.me.leaderboardVisible, isTrue);
    },
  );

  testWidgets('profil d’une personne : vérifié, à propos, préférences, badges, chiffres, écrire', (
    tester,
  ) async {
    await open(tester, AppRoutes.person('driver-1'));
    expect(find.text('Nathan, 20 ans'), findsOneWidget);
    expect(find.text('4,5/5 · 9 avis'), findsOneWidget);
    expect(find.text('Super Uni-Mooveur'), findsOneWidget);
    expect(find.text('Nathan a un profil vérifié'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Je préfère qu\'on ne fume pas en voiture'), 200);
    expect(find.text('J\'aime la musique en voiture'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Taux d\'annulation de 2 %'), 200);
    expect(find.text('Conducteur fidèle'), findsOneWidget);
    expect(find.text('85 kg de CO2 évités en covoiturant'), findsOneWidget);
  });

  testWidgets('à propos : centres d’intérêt proposés à toucher, préférences, mini-bio', (
    tester,
  ) async {
    await open(tester, AppRoutes.profileAbout);
    await tester.tap(find.bySemanticsLabel('Randonnée'));
    await tester.pump();
    await tester.ensureVisible(find.text('Je discute si je me sens à l\'aise'));
    await tester.tap(find.text('Je discute si je me sens à l\'aise'));
    await tester.pump();
    await tester.enterText(fieldLabeled('Mini-bio'), 'Toujours à l’heure.');
    await tapText(tester, 'Enregistrer');
    expect(backend.me.interests, ['Randonnée']);
    expect(backend.me.preferences.chat, 'depends');
    expect(backend.me.bio, 'Toujours à l’heure.');
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('accessibilité ${mode.name} : réussites et profil public', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, AppRoutes.achievements, mode: mode);
      await expectAccessible(tester);
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go(AppRoutes.person('driver-1'));
      await tester.pumpAndSettle();
      await expectAccessible(tester);
      handle.dispose();
    });
  }

  testWidgets('golden réussites', (tester) async {
    await open(tester, AppRoutes.achievements);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/achievements_light.png'),
    );
  });

  testWidgets('golden profil public', (tester) async {
    await open(tester, AppRoutes.person('driver-1'));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/public_profile_light.png'),
    );
  });
}
