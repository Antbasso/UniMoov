import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/ride.dart';

/// Connexion de suivi d'un trajet en cours (une salle par trajet, docs/api.md).
abstract interface class LiveConnection {
  Stream<LiveEvent> get events;

  /// Code de fermeture du serveur (4403 hors trajet, 4409 pas commencé, 4410 clôturé).
  Future<int?> get closeCode;
  void sendPosition({required double lat, required double lon, required DateTime at});
  Future<void> close();
}

abstract interface class LiveConnector {
  Future<LiveConnection> connect(String rideId);
}

/// Codes après lesquels on ne se reconnecte pas. 4401 (jeton expiré) n'en fait pas partie :
/// la reconnexion renouvelle le jeton.
const liveFinalCodes = {4403, 4409, 4410};

class WebSocketLiveConnector implements LiveConnector {
  const WebSocketLiveConnector(this._tokens);

  final TokenStorage _tokens;

  @override
  Future<LiveConnection> connect(String rideId) async {
    final token = (await _tokens.read())?.accessToken ?? '';
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/api/v1/ws/rides/$rideId',
      queryParameters: {'token': token},
    );
    final channel = WebSocketChannel.connect(uri);
    await channel.ready;
    return _WebSocketLiveConnection(channel);
  }
}

class _WebSocketLiveConnection implements LiveConnection {
  _WebSocketLiveConnection(this._channel)
    : events = _channel.stream
          .map((data) => LiveEvent.fromJson(jsonDecode(data as String) as Map<String, dynamic>))
          .where((e) => e != null)
          .cast<LiveEvent>()
          .asBroadcastStream();

  final WebSocketChannel _channel;

  @override
  final Stream<LiveEvent> events;

  @override
  Future<int?> get closeCode => _channel.sink.done.then((_) => _channel.closeCode);

  @override
  void sendPosition({required double lat, required double lon, required DateTime at}) {
    _channel.sink.add(
      jsonEncode({'type': 'position', 'lat': lat, 'lon': lon, 'ts': at.toUtc().toIso8601String()}),
    );
  }

  @override
  Future<void> close() => _channel.sink.close();
}

final liveConnectorProvider = Provider<LiveConnector>(
  (ref) => WebSocketLiveConnector(ref.watch(tokenStorageProvider)),
);
