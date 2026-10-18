import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:unimoov/core/router/redirect.dart';
import 'package:unimoov/core/storage/token_storage.dart';
import 'package:unimoov/features/auth/domain/auth_tokens.dart';
import 'package:unimoov/features/chat/domain/chat.dart';
import 'package:unimoov/features/profile/domain/me.dart';

import '../../support/app_harness.dart';
import '../../support/chat_fakes.dart';
import '../../support/fake_backend.dart';
import 'accessibility_test.dart' show expectAccessible;

/// M6 : messagerie (privé, groupe, chat de trajet), réception en direct, notifications.
void main() {
  late FakeBackend backend;
  late MemoryTokenStorage storage;
  const me = 'id-lea@etu.univ-smb.fr';
  const nathan = ChatMember(userId: 'driver-1', firstName: 'Nathan');
  const hugo = ChatMember(userId: 'passenger-3', firstName: 'Hugo');
  const ines = ChatMember(userId: 'passenger-2', firstName: 'Inès');

  setUp(() {
    backend = rideBackend()..contactList = [nathan, hugo, ines];
    storage = MemoryTokenStorage()..tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
    backend.conversationsById['conv-ride'] = const Conversation(
      id: 'conv-ride',
      kind: ConversationKind.ride,
      rideId: 'ride-1',
      archived: false,
      unread: 0,
      members: [
        ChatMember(userId: me, firstName: 'Léa'),
        nathan,
        hugo,
      ],
    );
    backend.rideChats['ride-1'] = 'conv-ride';
    backend.messagesById['conv-ride'] = [
      ChatMessage(
        id: 'm1',
        conversationId: 'conv-ride',
        senderId: 'driver-1',
        body: 'Je pars à 7 h 40.',
        createdAt: DateTime.utc(2026, 10, 15, 6, 10),
      ),
    ];
  });

  Future<void> open(
    WidgetTester tester,
    String location, {
    ThemeMode mode = ThemeMode.light,
    FakePushService? push,
  }) async {
    await launchApp(tester, backend: backend, storage: storage, themeMode: mode, push: push);
    if (location != AppRoutes.home) {
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('groupe : accepter une proposition de covoiturage, puis proposer mon trajet', (
    tester,
  ) async {
    backend.conversationsById['conv-group'] = const Conversation(
      id: 'conv-group',
      kind: ConversationKind.group,
      title: 'Covoit Seynod',
      archived: false,
      unread: 0,
      members: [
        ChatMember(userId: me, firstName: 'Léa'),
        nathan,
        hugo,
      ],
    );
    backend.messagesById['conv-group'] = [
      ChatMessage(
        id: 'offer-1',
        conversationId: 'conv-group',
        senderId: 'driver-1',
        body: 'Je propose un trajet.',
        createdAt: DateTime.utc(2026, 10, 15, 6, 10),
        carpool: Carpool(
          isOffer: true,
          rideId: 'ride-9',
          day: DateTime(2026, 10, 22),
          toCampus: true,
          time: DateTime.utc(2026, 10, 22, 6),
        ),
      ),
    ];
    // Un trajet que je conduis vendredi, à proposer au groupe.
    backend.weeks['2026-W42']!.add(
      proposalFixture(
        id: 'ride-7',
        day: DateTime(2026, 10, 16),
        isDriver: true,
        myStatus: 'accepted',
        rideStatus: 'confirmed',
      ),
    );
    // Avec une voiture : je peux aussi proposer de conduire.
    backend.me.vehicle = const Vehicle(
      consumptionLPer100km: 5.5,
      defaultSeats: 3,
      maxDetourMinutes: 10,
    );
    await open(tester, AppRoutes.conversation('conv-group'));
    expect(find.text('Trajet proposé · Nathan'), findsOneWidget);
    await tapText(tester, 'Je monte');
    expect(backend.carpoolAccepted, [('conv-group', 'offer-1')]);
    expect(find.textContaining("c'est réservé"), findsOneWidget);
    expect(find.text('Je monte'), findsNothing);

    // Créer mon trajet depuis la conversation : je conduis, aller à 8 h, retour programmé.
    // Le message de confirmation se retire avant d'ouvrir « + ».
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Joindre une photo ou un trajet'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Proposer un covoiturage');
    await tester.tap(find.bySemanticsLabel('vendredi 16 octobre'));
    await tester.pump();
    await tester.ensureVisible(find.text('Programmer le retour'));
    await tapText(tester, 'Programmer le retour');
    await tester.ensureVisible(find.text('Proposer ce trajet'));
    await tapText(tester, 'Proposer ce trajet');
    expect(backend.carpoolPosts.map((p) => (p.toCampus, p.time, p.create)), [
      (true, '08:00', true),
      (false, '17:00', true),
    ]);
    expect(backend.carpoolPosts.first.day, DateTime(2026, 10, 16));
    // Les deux cartes s'affichent ; la mienne ouvre le trajet créé.
    expect(find.text('Trajet proposé'), findsNWidgets(2));
    expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);
  });

  testWidgets('accueil : pastille des non lus, liste des conversations', (tester) async {
    await open(tester, AppRoutes.home);
    expect(find.byTooltip('Messages'), findsOneWidget);
    backend.receive('conv-ride', 'driver-1', 'Petit retard, 5 min.');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Messages, 1 non lu'), findsOneWidget);

    final before = backend.conversationCalls;
    await tester.tap(find.byTooltip('Messages, 1 non lu'));
    await tester.pumpAndSettle();
    expect(find.text('Chat du trajet'), findsOneWidget);
    expect(find.text('1 non lu'), findsOneWidget);
    expect(find.text('Petit retard, 5 min.'), findsOneWidget);
    // Ouverture : la conversation vient de la liste, seuls les messages sont chargés.
    await tapText(tester, 'Petit retard, 5 min.');
    expect(find.text('Je pars à 7 h 40.'), findsOneWidget);
    expect(backend.conversationCalls, before);
  });

  testWidgets('conversation : envoi, réception en direct avec le prénom, lecture', (tester) async {
    await open(tester, AppRoutes.conversation('conv-ride'));
    expect(find.text('Je pars à 7 h 40.'), findsOneWidget);
    expect(find.text('Nathan'), findsWidgets); // auteur d'un message de groupe
    expect(backend.readConversations, contains('conv-ride'));

    // Rien à envoyer : bouton désactivé.
    expect(
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send_rounded)).onPressed,
      isNull,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Écris un message'),
      'Merci, à tout à l’heure.',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Envoyer'));
    await tester.pumpAndSettle();
    expect(find.text('Merci, à tout à l’heure.'), findsOneWidget);
    expect(backend.messagesById['conv-ride']!.last.body, 'Merci, à tout à l’heure.');

    backend.receive('conv-ride', 'passenger-3', 'Je suis au point de rendez-vous.');
    await tester.pumpAndSettle();
    expect(find.text('Je suis au point de rendez-vous.'), findsOneWidget);
    expect(find.text('Hugo'), findsWidgets);
  });

  testWidgets('réagir d’un appui long, retirer d’un toucher ; envoyer une photo légendée', (
    tester,
  ) async {
    await open(tester, AppRoutes.conversation('conv-ride'));
    await tester.longPress(find.text('Je pars à 7 h 40.'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Réagir avec 👍'));
    await tester.pumpAndSettle();
    expect(backend.reactionsSent.last.$2, '👍');
    final pill = find.bySemanticsLabel('Ta réaction 👍, 1. Touche pour la retirer');
    expect(pill, findsOneWidget);
    await tester.tap(pill);
    await tester.pumpAndSettle();
    expect(backend.reactionsSent.last.$2, isNull);
    expect(pill, findsNothing);

    // Photo : le texte en cours devient sa légende.
    await tester.enterText(find.widgetWithText(TextField, 'Écris un message'), 'Je suis là');
    await tester.tap(find.byTooltip('Joindre une photo ou un trajet'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Choisir une photo');
    expect(backend.chatPhotos.single.$2, 'Je suis là');
    expect(find.bySemanticsLabel(RegExp('^Photo')), findsOneWidget);
  });

  testWidgets('chat de trajet archivé : lecture seule', (tester) async {
    backend.conversationsById['conv-ride'] = const Conversation(
      id: 'conv-ride',
      kind: ConversationKind.ride,
      rideId: 'ride-1',
      archived: true,
      unread: 0,
      members: [
        ChatMember(userId: me, firstName: 'Léa'),
        nathan,
      ],
    );
    await open(tester, AppRoutes.conversation('conv-ride'));
    expect(
      find.text('Ce chat de trajet est archivé : tu peux le relire, plus y écrire.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Envoyer'), findsNothing);
  });

  testWidgets('nouveau message privé à une personne croisée', (tester) async {
    await open(tester, AppRoutes.messages);
    await tapText(tester, 'Nouveau message');
    await tapText(tester, 'Inès');
    await tapText(tester, 'Écrire');
    expect(find.text('Inès'), findsWidgets); // titre de la conversation privée
    expect(find.text('Aucun message pour l\'instant. Lance la conversation.'), findsOneWidget);
  });

  testWidgets('nouveau groupe : plusieurs personnes et un nom, puis le quitter', (tester) async {
    await open(tester, AppRoutes.messages);
    await tapText(tester, 'Nouveau message');
    await tapText(tester, 'Hugo');
    await tapText(tester, 'Inès');
    await tester.enterText(fieldLabeled('Nom du groupe'), 'Seynod le lundi');
    await tester.pump();
    await tapText(tester, 'Créer le groupe');
    expect(find.text('Seynod le lundi'), findsOneWidget);
    await tester.tap(find.byTooltip('Quitter le groupe'));
    await tester.pumpAndSettle();
    expect(find.text('Quitter le groupe ?'), findsOneWidget);
    await tapText(tester, 'Quitter');
    expect(
      backend.conversationsById.values.where((c) => c.kind == ConversationKind.group),
      isEmpty,
    );
  });

  testWidgets('écran du trajet : accès direct au chat du trajet', (tester) async {
    await launchApp(tester, backend: backend, storage: storage);
    await openTrip(tester, index: 0);
    await tester.tap(find.byTooltip('Chat du trajet'));
    await tester.pumpAndSettle();
    expect(find.text('Je pars à 7 h 40.'), findsOneWidget);
  });

  testWidgets('depuis l’accueil : l’icône du chat ouvre la conversation dans Messages', (
    tester,
  ) async {
    await launchApp(tester, backend: backend, storage: storage);
    await openTrip(tester, index: 0);
    await tester.tap(find.byTooltip('Chat du trajet'));
    await tester.pumpAndSettle();
    expect(find.text('Je pars à 7 h 40.'), findsOneWidget);
    // Le trajet est épinglé en haut de sa conversation.
    expect(find.text('Voir le trajet'), findsOneWidget);
    // Retour : la liste des conversations, onglet Messages actif.
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    // Titre de la liste et libellé de l'onglet.
    expect(find.text('Messages'), findsNWidgets(2));
  });

  testWidgets('préférences : couper le chat, garder les rappels', (tester) async {
    await open(tester, AppRoutes.notificationSettings);
    expect(find.text('Rappel de trajet'), findsOneWidget);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Messages'));
    await tester.pumpAndSettle();
    expect(backend.preferencesState.chat, isFalse);
    expect(backend.preferencesState.rideReminder, isTrue);
  });

  testWidgets(
    'push : appareil enregistré, notification touchée ouvre le chat, déconnexion le retire',
    (tester) async {
      final push = FakePushService();
      await open(tester, AppRoutes.home, push: push);
      expect(backend.devices, ['jeton-appareil-test']);

      push.tap({'type': 'chat_message', 'conversationId': 'conv-ride'});
      await tester.pumpAndSettle();
      expect(find.text('Je pars à 7 h 40.'), findsOneWidget);

      // Déconnexion depuis le profil.
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go(AppRoutes.profile);
      await tester.pumpAndSettle();
      await tapText(tester, 'Me déconnecter');
      expect(backend.devices, isEmpty);
    },
  );

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('accessibilité ${mode.name} : messages, conversation, préférences', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, AppRoutes.messages, mode: mode);
      await expectAccessible(tester);
      await open(tester, AppRoutes.conversation('conv-ride'), mode: mode);
      await expectAccessible(tester);
      await open(tester, AppRoutes.notificationSettings, mode: mode);
      await expectAccessible(tester);
      handle.dispose();
    });
  }

  testWidgets('golden messages', (tester) async {
    backend.conversationsById['conv-ines'] = Conversation(
      id: 'conv-ines',
      kind: ConversationKind.direct,
      archived: false,
      unread: 2,
      members: const [
        ChatMember(userId: me, firstName: 'Léa'),
        ines,
      ],
      lastMessage: ChatMessage(
        id: 'm9',
        conversationId: 'conv-ines',
        senderId: 'passenger-2',
        body: 'On fait le trajet ensemble jeudi ?',
        createdAt: DateTime.utc(2026, 10, 15, 7, 2),
      ),
    );
    await open(tester, AppRoutes.messages);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/messages_light.png'));
  });

  testWidgets('golden conversation', (tester) async {
    backend.messagesById['conv-ride']!.add(
      ChatMessage(
        id: 'm2',
        conversationId: 'conv-ride',
        senderId: me,
        body: 'Parfait, je serai au point de rendez-vous.',
        createdAt: DateTime.utc(2026, 10, 15, 6, 12),
      ),
    );
    await open(tester, AppRoutes.conversation('conv-ride'));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/conversation_light.png'),
    );
  });
}
