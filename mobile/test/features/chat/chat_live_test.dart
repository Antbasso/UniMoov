import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/features/chat/data/user_socket.dart';
import 'package:unimoov/features/chat/domain/chat.dart';
import 'package:unimoov/features/chat/presentation/chat_controller.dart';

/// Connexion pilotée par le test : prête ou refusée (4401), fermée à la demande.
class _Connection implements UserSocketConnection {
  _Connection({required this.accepted});

  final bool accepted;
  final _done = Completer<int?>();
  final controller = StreamController<ChatMessage>.broadcast();

  @override
  Stream<ChatMessage> get messages => controller.stream;
  @override
  Future<void> get ready => accepted ? Future.value() : Completer<void>().future;
  @override
  Future<int?> get done => _done.future;

  void serverClose(int code) {
    if (!_done.isCompleted) _done.complete(code);
  }

  @override
  Future<void> close() async => serverClose(1000);
}

class _Connector implements UserSocketConnector {
  final List<_Connection> connections = [];
  bool accept = true;

  @override
  Future<UserSocketConnection> connect() async {
    final c = _Connection(accepted: accept);
    connections.add(c);
    if (!accept) c.serverClose(4401);
    return c;
  }
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  test('délai par défaut : 2 s après un jeton refusé, puis croissant jusqu’à 30 s', () {
    expect(ChatLive.defaultRetryDelay(5, 4401), const Duration(seconds: 2));
    expect(ChatLive.defaultRetryDelay(1, 1006), const Duration(seconds: 2));
    expect(ChatLive.defaultRetryDelay(3, 1006), const Duration(seconds: 8));
    expect(ChatLive.defaultRetryDelay(9, null), const Duration(seconds: 30));
  });

  test('coupure : reconnexion, puis signal « reconnecté » pour relire', () async {
    final connector = _Connector();
    var refreshed = 0;
    final live = ChatLive(
      connector,
      refreshSession: () async => refreshed++,
      retryDelay: (_, _) => Duration.zero,
    );
    var reconnected = 0;
    final sub = live.reconnected.listen((_) => reconnected++);
    live.start();
    await _settle();
    expect(connector.connections, hasLength(1));

    connector.connections.last.serverClose(1006);
    await _settle();

    await _settle();
    await _settle();
    expect(connector.connections, hasLength(2));
    expect(refreshed, 1); // jeton renouvelé avant de réessayer
    expect(reconnected, 1);
    await sub.cancel();
    await live.dispose();
  });

  test('jeton refusé (4401) : jeton renouvelé avant chaque nouvel essai', () async {
    final connector = _Connector()..accept = false;
    var refreshed = 0;
    final live = ChatLive(
      connector,
      refreshSession: () async => refreshed++,
      retryDelay: (_, _) => const Duration(milliseconds: 20),
    );
    live.start();
    await _settle();
    expect(connector.connections, hasLength(1));
    connector.accept = true;
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(connector.connections, hasLength(2));
    expect(refreshed, 1);
    await live.dispose();
  });

  test('arrière-plan : socket fermé, aucune reconnexion avant le retour', () async {
    final connector = _Connector();
    final live = ChatLive(connector, retryDelay: (_, _) => const Duration(milliseconds: 10));
    live.start();
    await _settle();
    await live.pause();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(connector.connections, hasLength(1));
    live.start();
    await _settle();
    expect(connector.connections, hasLength(2));
    await live.dispose();
  });
}
