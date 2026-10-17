import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/session_controller.dart';
import '../data/chat_api.dart';
import '../data/user_socket.dart';
import '../domain/chat.dart';

/// Messages reçus en direct par `GET /ws/me`, avec reconnexion à délai croissant (1 s à 30 s).
class ChatLive {
  ChatLive(this._connector);

  final UserSocketConnector _connector;
  final _messages = StreamController<ChatMessage>.broadcast();
  UserSocketConnection? _connection;
  Timer? _retry;
  int _attempt = 0;
  bool _stopped = false;

  Stream<ChatMessage> get messages => _messages.stream;

  void start() => unawaited(_connect());

  Future<void> _connect() async {
    if (_stopped) return;
    try {
      final connection = await _connector.connect();
      if (_stopped) {
        await connection.close();
        return;
      }
      _connection = connection;
      _attempt = 0;
      final sub = connection.messages.listen(_messages.add, onError: (Object _) {});
      await connection.done;
      await sub.cancel();
    } on Object {
      // Hors ligne ou serveur indisponible : nouvel essai plus tard.
    }
    if (_stopped) return;
    _attempt++;
    _retry = Timer(Duration(seconds: min(30, 1 << min(_attempt, 5))), () => unawaited(_connect()));
  }

  Future<void> dispose() async {
    _stopped = true;
    _retry?.cancel();
    await _connection?.close();
    await _messages.close();
  }
}

/// Connecté seulement pendant une session ; recréé à chaque connexion ou déconnexion.
final chatLiveProvider = Provider<ChatLive>((ref) {
  final signedIn = ref.watch(sessionProvider.select((s) => s.value == SessionStatus.signedIn));
  final live = ChatLive(ref.watch(userSocketConnectorProvider));
  if (signedIn) live.start();
  ref.onDispose(() => unawaited(live.dispose()));
  return live;
});

/// Mes conversations ; relues à chaque message reçu (non lus, ordre).
class ConversationsController extends AsyncNotifier<List<Conversation>> {
  @override
  Future<List<Conversation>> build() {
    final sub = ref.watch(chatLiveProvider).messages.listen((_) => ref.invalidateSelf());
    ref.onDispose(sub.cancel);
    return ref.watch(chatApiProvider).conversations();
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
