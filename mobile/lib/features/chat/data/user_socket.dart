import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/chat.dart';
import '../../demo/demo_mode.dart';

/// Socket utilisateur `GET /ws/me` : messages reçus en direct (docs/api.md).
abstract interface class UserSocketConnection {
  Stream<ChatMessage> get messages;

  /// Le serveur a accepté le jeton (`{type: ready}`).
  Future<void> get ready;

  /// Fin de la connexion (code de fermeture du serveur, `null` si coupée).
  Future<int?> get done;
  Future<void> close();
}

abstract interface class UserSocketConnector {
  Future<UserSocketConnection> connect();
}

class WebSocketUserConnector implements UserSocketConnector {
  const WebSocketUserConnector(this._tokens);

  final TokenStorage _tokens;

  @override
  Future<UserSocketConnection> connect() async {
    final token = (await _tokens.read())?.accessToken ?? '';
    final base = Uri.parse(apiBaseUrl);
    final channel = WebSocketChannel.connect(
      base.replace(
        scheme: base.scheme == 'https' ? 'wss' : 'ws',
        path: '/api/v1/ws/me',
        queryParameters: {'token': token},
      ),
    );
    await channel.ready;
    return _Connection(channel);
  }
}

class _Connection implements UserSocketConnection {
  _Connection(this._channel) {
    final events = _channel.stream
        .map((data) => jsonDecode(data as String) as Map<String, dynamic>)
        .asBroadcastStream();
    messages = events
        .where((json) => json['type'] == 'message')
        .map((json) => ChatMessage.fromJson(json['message'] as Map<String, dynamic>))
        .asBroadcastStream();
    ready = events.firstWhere((json) => json['type'] == 'ready').then((_) {});
  }

  final WebSocketChannel _channel;

  @override
  late final Stream<ChatMessage> messages;

  @override
  late final Future<void> ready;

  @override
  Future<int?> get done => _channel.sink.done.then((_) => _channel.closeCode);

  @override
  Future<void> close() => _channel.sink.close();
}

final userSocketConnectorProvider = Provider<UserSocketConnector>(
  (ref) =>
      ref.watch(demoProvider)?.chatSocket ??
      WebSocketUserConnector(ref.watch(tokenStorageProvider)),
);
