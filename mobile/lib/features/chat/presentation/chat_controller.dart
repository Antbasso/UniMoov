import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/session_controller.dart';
import '../data/chat_api.dart';
import '../data/user_socket.dart';
import '../domain/chat.dart';

/// Messages reçus en direct par `GET /ws/me`, avec reconnexion à délai croissant (2 s à 30 s).
/// Coupé en arrière-plan (le serveur envoie alors des push), rouvert au retour.
class ChatLive {
  ChatLive(this._connector, {this.refreshSession, this.retryDelay = defaultRetryDelay});

  /// 2 s après un jeton refusé, sinon délai doublé à chaque échec, plafonné à 30 s.
  static Duration defaultRetryDelay(int attempt, int? closeCode) =>
      Duration(seconds: closeCode == 4401 ? 2 : min(30, 1 << min(attempt, 5)));

  final Duration Function(int attempt, int? closeCode) retryDelay;

  final UserSocketConnector _connector;

  /// Appel authentifié qui renouvelle le jeton d'accès (l'intercepteur s'en charge).
  final Future<void> Function()? refreshSession;
  final _messages = StreamController<ChatMessage>.broadcast();
  final _reconnected = StreamController<void>.broadcast();
  UserSocketConnection? _connection;
  Timer? _retry;
  int _attempt = 0;
  bool _running = false;
  bool _disposed = false;
  bool _connectedOnce = false;

  /// Conversations ouvertes à l'écran : leurs messages sont lus à mesure.
  final Set<String> open = {};

  Stream<ChatMessage> get messages => _messages.stream;

  /// Reconnecté après une coupure : des messages ont pu être manqués, à relire.
  Stream<void> get reconnected => _reconnected.stream;

  /// Change à chaque pause ou reprise : une connexion lancée avant n'est plus la bonne.
  int _generation = 0;

  void start() {
    if (_running || _disposed) return;
    _running = true;
    _generation++;
    unawaited(_connect());
  }

  /// Arrière-plan : socket fermé, plus de reconnexion jusqu'au retour.
  Future<void> pause() async {
    _running = false;
    _generation++;
    _retry?.cancel();
    final connection = _connection;
    _connection = null;
    await connection?.close();
  }

  Future<void> _connect() async {
    if (!_running) return;
    final generation = _generation;
    bool current() => _running && generation == _generation;
    int? code;
    try {
      // Jeton refusé à la dernière tentative : on le renouvelle avant de réessayer.
      if (_attempt > 0) await refreshSession?.call();
      final connection = await _connector.connect();
      // Mis en pause (puis peut-être repris) pendant la connexion : celle-ci est de trop.
      if (!current()) {
        await connection.close();
        return;
      }
      _connection = connection;
      final sub = connection.messages.listen(_messages.add, onError: (Object _) {});
      final done = connection.done;
      // Prête (jeton accepté) ou fermée avant (4401) : seule la première compte comme réussie.
      final accepted = await Future.any<bool>([
        connection.ready.then((_) => true),
        done.then((_) => false),
      ]);
      if (accepted && current() && _connection == connection) {
        // Accepté par le serveur : le délai repart du minimum.
        _attempt = 0;
        if (_connectedOnce) _reconnected.add(null);
        _connectedOnce = true;
      }
      code = await done;
      await sub.cancel();
    } on Object {
      // Hors ligne, serveur indisponible ou session expirée : nouvel essai plus tard.
    }
    if (!current()) return;
    _attempt++;
    _retry = Timer(retryDelay(_attempt, code), () => unawaited(_connect()));
  }

  Future<void> dispose() async {
    _disposed = true;
    await pause();
    await _messages.close();
    await _reconnected.close();
  }
}

/// Connecté seulement pendant une session et au premier plan ; recréé à chaque connexion ou
/// déconnexion.
final chatLiveProvider = Provider<ChatLive>((ref) {
  final signedIn = ref.watch(sessionProvider.select((s) => s.value == SessionStatus.signedIn));
  final live = ChatLive(
    ref.watch(userSocketConnectorProvider),
    refreshSession: () => ref.read(chatApiProvider).conversations(),
  );
  if (signedIn) {
    live.start();
    final lifecycle = AppLifecycleListener(
      onPause: () => unawaited(live.pause()),
      onResume: live.start,
    );
    ref.onDispose(lifecycle.dispose);
  }
  ref.onDispose(() => unawaited(live.dispose()));
  return live;
});

/// Mes conversations ; relues à chaque message reçu (non lus, ordre).
class ConversationsController extends AsyncNotifier<List<Conversation>> {
  @override
  Future<List<Conversation>> build() async {
    final live = ref.watch(chatLiveProvider);
    final subs = [
      live.messages.listen((_) => ref.invalidateSelf()),
      live.reconnected.listen((_) => ref.invalidateSelf()),
    ];
    ref.onDispose(() {
      for (final s in subs) {
        unawaited(s.cancel());
      }
    });
    final list = await ref.watch(chatApiProvider).conversations();
    // Conversation ouverte à l'écran : ses messages sont lus à mesure, pas de pastille.
    return [for (final c in list) live.open.contains(c.id) ? c.copyWith(unread: 0) : c];
  }

  /// Conversation lue : son compteur repasse à zéro sans recharger.
  void markRead(String id) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData([for (final c in current) c.id == id ? c.copyWith(unread: 0) : c]);
  }
}

final conversationsProvider = AsyncNotifierProvider<ConversationsController, List<Conversation>>(
  ConversationsController.new,
  retry: (retryCount, error) => null,
);

/// Nombre total de messages non lus (pastille de l'accueil).
final unreadCountProvider = Provider<int>(
  (ref) => (ref.watch(conversationsProvider).value ?? const []).fold(0, (sum, c) => sum + c.unread),
);

class ConversationState {
  const ConversationState({
    required this.conversation,
    required this.messages,
    required this.hasMore,
  });

  final Conversation conversation;

  /// Du plus ancien au plus récent.
  final List<ChatMessage> messages;
  final bool hasMore;

  ConversationState copyWith({List<ChatMessage>? messages, bool? hasMore}) => ConversationState(
    conversation: conversation,
    messages: messages ?? this.messages,
    hasMore: hasMore ?? this.hasMore,
  );
}

const _pageSize = 50;

/// Conversation ouverte : messages, envoi, réception en direct, lecture.
class ConversationController extends AsyncNotifier<ConversationState> {
  ConversationController(this.id);

  final String id;

  ChatApi get _api => ref.read(chatApiProvider);

  @override
  Future<ConversationState> build() async {
    final api = ref.watch(chatApiProvider);
    final sub = ref
        .watch(chatLiveProvider)
        .messages
        .where((m) => m.conversationId == id)
        .listen(_received);
    ref.onDispose(sub.cancel);
    final conversation = await api.conversation(id);
    final page = await api.messages(id);
    unawaited(_read());
    return ConversationState(
      conversation: conversation,
      messages: page.reversed.toList(),
      hasMore: page.length >= _pageSize,
    );
  }

  Future<void> _read() async {
    try {
      await _api.markRead(id);
      if (ref.mounted) ref.read(conversationsProvider.notifier).markRead(id);
    } on Object {
      // Le compteur sera juste à la prochaine lecture.
    }
  }

  void _append(ChatMessage message) {
    final current = state.value;
    if (current == null || current.messages.any((m) => m.id == message.id)) return;
    state = AsyncData(current.copyWith(messages: [...current.messages, message]));
  }

  void _received(ChatMessage message) {
    _append(message);
    unawaited(_read());
  }

  Future<void> send(String body) async {
    final message = await _api.send(id, body);
    if (ref.mounted) _append(message);
  }

  Future<void> loadOlder() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.messages.isEmpty) return;
    final older = await _api.messages(id, before: current.messages.first.createdAt);
    if (!ref.mounted) return;
    state = AsyncData(
      current.copyWith(
        messages: [...older.reversed, ...current.messages],
        hasMore: older.length >= _pageSize,
      ),
    );
  }

  Future<void> leave() async {
    await _api.leave(id);
    if (ref.mounted) ref.invalidate(conversationsProvider);
  }
}

final conversationProvider = AsyncNotifierProvider.autoDispose
    .family<ConversationController, ConversationState, String>(
      ConversationController.new,
      retry: (retryCount, error) => null,
    );

final contactsProvider = FutureProvider.autoDispose<List<ChatMember>>(
  (ref) => ref.watch(chatApiProvider).contacts(),
  retry: (retryCount, error) => null,
);
