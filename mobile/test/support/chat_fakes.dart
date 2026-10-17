import 'dart:async';

import 'package:unimoov/features/chat/data/user_socket.dart';
import 'package:unimoov/features/chat/domain/chat.dart';
import 'package:unimoov/features/notifications/data/push_service.dart';

/// Socket `/ws/me` simulé : les messages émis arrivent aux connexions ouvertes.
class FakeUserSocketConnector implements UserSocketConnector {
  final List<_FakeConnection> _open = [];
  int connects = 0;

  @override
  Future<UserSocketConnection> connect() async {
    connects++;
    final connection = _FakeConnection();
    _open.add(connection);
    return connection;
  }

  void emit(ChatMessage message) {
    for (final c in _open.where((c) => !c.closed)) {
      c.controller.add(message);
    }
  }
}

class _FakeConnection implements UserSocketConnection {
  final controller = StreamController<ChatMessage>.broadcast();
  final _done = Completer<int?>();
  bool closed = false;

  @override
  Stream<ChatMessage> get messages => controller.stream;

  @override
  Future<int?> get done => _done.future;

  @override
  Future<void> close() async {
    closed = true;
    if (!_done.isCompleted) _done.complete(1000);
    await controller.close();
  }
}

/// Push simulé : jeton fixe, notifications touchées émises à la demande.
class FakePushService implements PushService {
  FakePushService({this.deviceToken = 'jeton-appareil-test'});

  final String? deviceToken;
  final _opened = StreamController<Map<String, String>>.broadcast();
  Map<String, String>? initial;

  void tap(Map<String, String> data) => _opened.add(data);

  @override
  Future<String?> token() async => deviceToken;
  @override
  Stream<String> get tokenRefresh => const Stream.empty();
  @override
  Stream<Map<String, String>> get opened => _opened.stream;
  @override
  Future<Map<String, String>?> initialOpened() async => initial;
}
