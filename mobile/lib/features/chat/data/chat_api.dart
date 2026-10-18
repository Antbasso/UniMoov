import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/authenticated_dio.dart';
import '../domain/chat.dart';
import '../../demo/demo_mode.dart';

abstract interface class ChatApi {
  Future<List<Conversation>> conversations();
  Future<Conversation> conversation(String id);

  /// Chat d'un trajet confirmé dont je fais partie.
  Future<Conversation> rideConversation(String rideId);

  /// Personnes croisées sur un trajet : seules joignables.
  Future<List<ChatMember>> contacts();
  Future<Conversation> createDirect(String userId);
  Future<Conversation> createGroup(String title, List<String> userIds);

  /// Messages du plus récent au plus ancien ; `before` pour remonter.
  Future<List<ChatMessage>> messages(String id, {DateTime? before, String? beforeId});
  Future<ChatMessage> send(String id, String body);

  /// Proposition de covoiturage : offre sur un trajet que je conduis (`rideId`), offre sur un
  /// trajet créé pour l'occasion (`create` : jour, sens, heure « HH:MM »), ou demande (jour,
  /// sens, heure facultative).
  Future<ChatMessage> postCarpool(
    String id, {
    String? rideId,
    DateTime? day,
    bool toCampus = true,
    String? time,
    bool create = false,
  });

  /// Accepter une proposition : je monte (offre) ou je prends la personne (demande).
  Future<ChatMessage> acceptCarpool(String id, String messageId);
  Future<void> markRead(String id);
  Future<void> leave(String id);
}

class DioChatApi implements ChatApi {
  const DioChatApi(this._dio);

  final Dio _dio;

  Future<Conversation> _one(Future<Response<Map<String, dynamic>>> request) =>
      guardApi(() async => Conversation.fromJson((await request).data!));

  @override
  Future<List<Conversation>> conversations() => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/conversations');
    return [
      for (final c in response.data!['conversations'] as List<dynamic>)
        Conversation.fromJson(c as Map<String, dynamic>),
    ];
  });

  @override
  Future<Conversation> conversation(String id) =>
      _one(_dio.get<Map<String, dynamic>>('/api/v1/conversations/$id'));

  @override
  Future<Conversation> rideConversation(String rideId) =>
      _one(_dio.get<Map<String, dynamic>>('/api/v1/rides/$rideId/conversation'));

  @override
  Future<List<ChatMember>> contacts() => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/contacts');
    return [
      for (final c in response.data!['contacts'] as List<dynamic>)
        ChatMember.fromJson(c as Map<String, dynamic>),
    ];
  });

  @override
  Future<Conversation> createDirect(String userId) => _one(
    _dio.post<Map<String, dynamic>>(
      '/api/v1/conversations',
      data: {
        'kind': 'direct',
        'memberIds': [userId],
      },
    ),
  );

  @override
  Future<Conversation> createGroup(String title, List<String> userIds) => _one(
    _dio.post<Map<String, dynamic>>(
      '/api/v1/conversations',
      data: {'kind': 'group', 'title': title, 'memberIds': userIds},
    ),
  );

  @override
  Future<List<ChatMessage>> messages(String id, {DateTime? before, String? beforeId}) =>
      guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/api/v1/conversations/$id/messages',
          queryParameters: {
            if (before != null) 'before': before.toUtc().toIso8601String(),
            'beforeId': ?beforeId,
          },
        );
        return [
          for (final m in response.data!['messages'] as List<dynamic>)
            ChatMessage.fromJson(m as Map<String, dynamic>),
        ];
      });

  @override
  Future<ChatMessage> send(String id, String body) => guardApi(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/conversations/$id/messages',
      data: {'body': body},
    );
    return ChatMessage.fromJson(response.data!);
  });

  @override
  Future<ChatMessage> postCarpool(
    String id, {
    String? rideId,
    DateTime? day,
    bool toCampus = true,
    String? time,
    bool create = false,
  }) => guardApi(() async {
    final slot = {
      'day': day == null ? null : DateFormat('yyyy-MM-dd').format(day),
      'direction': toCampus ? 'to_campus' : 'from_campus',
    };
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/conversations/$id/carpool',
      data: rideId != null
          ? {'kind': 'offer', 'rideId': rideId}
          : create
          ? {
              'kind': 'offer',
              'create': {...slot, 'time': time},
            }
          : {'kind': 'request', ...slot, 'time': ?time},
    );
    return ChatMessage.fromJson(response.data!);
  });

  @override
  Future<ChatMessage> acceptCarpool(String id, String messageId) => guardApi(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/conversations/$id/messages/$messageId/carpool/accept',
    );
    return ChatMessage.fromJson(response.data!);
  });

  @override
  Future<void> markRead(String id) =>
      guardApi(() => _dio.post<void>('/api/v1/conversations/$id/read'));

  @override
  Future<void> leave(String id) =>
      guardApi(() => _dio.delete<void>('/api/v1/conversations/$id/members/me'));
}

final chatApiProvider = Provider<ChatApi>(
  (ref) => ref.watch(demoProvider) ?? DioChatApi(ref.watch(dioProvider)),
);
