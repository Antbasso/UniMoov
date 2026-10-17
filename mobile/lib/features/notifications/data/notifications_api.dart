import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/authenticated_dio.dart';

/// Préférences par catégorie (cahier §11) ; toutes activées par défaut.
class NotificationPreferences {
  const NotificationPreferences({
    this.match = true,
    this.rideUpdate = true,
    this.rideReminder = true,
    this.chat = true,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) => NotificationPreferences(
    match: json['match'] as bool,
    rideUpdate: json['rideUpdate'] as bool,
    rideReminder: json['rideReminder'] as bool,
    chat: json['chat'] as bool,
  );

  final bool match;
  final bool rideUpdate;
  final bool rideReminder;
  final bool chat;

  Map<String, bool> toJson() => {
    'match': match,
    'rideUpdate': rideUpdate,
    'rideReminder': rideReminder,
    'chat': chat,
  };
}

abstract interface class NotificationsApi {
  Future<void> registerDevice(String token);
  Future<void> unregisterDevice(String token);
  Future<NotificationPreferences> preferences();
  Future<NotificationPreferences> setPreferences(NotificationPreferences prefs);
}

class DioNotificationsApi implements NotificationsApi {
  const DioNotificationsApi(this._dio);

  final Dio _dio;

  @override
  Future<void> registerDevice(String token) => guardApi(
    () => _dio.post<void>(
      '/api/v1/devices',
      data: {
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        'pushToken': token,
      },
    ),
  );

  @override
  Future<void> unregisterDevice(String token) =>
      guardApi(() => _dio.delete<void>('/api/v1/devices', data: {'pushToken': token}));

  @override
  Future<NotificationPreferences> preferences() => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/me/notification-preferences');
    return NotificationPreferences.fromJson(response.data!);
  });

  @override
  Future<NotificationPreferences> setPreferences(NotificationPreferences prefs) =>
      guardApi(() async {
        final response = await _dio.put<Map<String, dynamic>>(
          '/api/v1/me/notification-preferences',
          data: prefs.toJson(),
        );
        return NotificationPreferences.fromJson(response.data!);
      });
}

final notificationsApiProvider = Provider<NotificationsApi>(
  (ref) => DioNotificationsApi(ref.watch(dioProvider)),
);
