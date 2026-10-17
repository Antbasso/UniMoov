import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/authenticated_dio.dart';
import '../domain/chat.dart';

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
  Future<void> markRead(String id) =>
      guardApi(() => _dio.post<void>('/api/v1/conversations/$id/read'));

  @override
  Future<void> leave(String id) =>
      guardApi(() => _dio.delete<void>('/api/v1/conversations/$id/members/me'));
}

final chatApiProvider = Provider<ChatApi>((ref) => DioChatApi(ref.watch(dioProvider)));
