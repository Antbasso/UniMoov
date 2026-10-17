import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../firebase_options.dart';

/// Notifications push de l'appareil (FCM), derrière une interface : remplaçable en test et
/// inactive tant que Firebase n'est pas configuré.
abstract interface class PushService {
  /// Demande l'autorisation (Android 13+, iOS) puis renvoie le jeton de l'appareil, ou `null`
  /// (refusé, Firebase absent, hors ligne).
  Future<String?> token();
  Stream<String> get tokenRefresh;

  /// Jeton actuel sans demander d'autorisation (déconnexion), ou `null`.
  Future<String?> currentToken();

  /// Données d'une notification touchée (application ouverte ou en arrière-plan).
  Stream<Map<String, String>> get opened;

  /// Notification qui a lancé l'application, s'il y en a une.
  Future<Map<String, String>?> initialOpened();

  /// Notifications refusées dans les réglages du téléphone (sans redemander).
  Future<bool> isBlocked();

  /// Réglages de l'application dans le système, pour réactiver les notifications.
  Future<void> openSettings();
}

/// Rien n'est envoyé ni reçu : Firebase non configuré.
class DisabledPushService implements PushService {
  const DisabledPushService();

  @override
  Future<String?> token() async => null;
  @override
  Future<String?> currentToken() async => null;
  @override
  Stream<String> get tokenRefresh => const Stream.empty();
  @override
  Stream<Map<String, String>> get opened => const Stream.empty();
  @override
  Future<Map<String, String>?> initialOpened() async => null;
  @override
  Future<bool> isBlocked() async => false;
  @override
  Future<void> openSettings() async {}
}

class FirebasePushService implements PushService {
  FirebasePushService(this._options);

  final FirebaseOptions _options;
  Future<FirebaseMessaging?>? _ready;

  Future<FirebaseMessaging?> _messaging() => _ready ??= () async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: _options);
      return FirebaseMessaging.instance;
    } on Object catch (error) {
      debugPrint('Firebase indisponible : $error');
      return null;
    }
  }();

  static Map<String, String> _data(RemoteMessage m) => m.data.map((k, v) => MapEntry(k, '$v'));

  @override
  Future<String?> token() async {
    final messaging = await _messaging();
    if (messaging == null) return null;
    try {
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return null;
      // Jeton d'enregistrement : c'est la cible de l'envoi FCM HTTP v1 côté serveur
      // (`register()`/`onRegistered` donnent un identifiant d'installation, pas ce jeton).
      // ignore: deprecated_member_use
      return await messaging.getToken();
    } on Object {
      return null;
    }
  }

  @override
  Future<String?> currentToken() async {
    try {
      // Même raison que dans `token()`.
      // ignore: deprecated_member_use
      return await (await _messaging())?.getToken();
    } on Object {
      return null;
    }
  }

  @override
  Stream<String> get tokenRefresh => Stream.fromFuture(_messaging()).asyncExpand(
    // Même raison que `getToken` ci-dessus.
    // ignore: deprecated_member_use
    (m) => m?.onTokenRefresh ?? const Stream<String>.empty(),
  );

  @override
  Stream<Map<String, String>> get opened => Stream.fromFuture(_messaging()).asyncExpand(
    (m) => m == null
        ? const Stream<Map<String, String>>.empty()
        : FirebaseMessaging.onMessageOpenedApp.map(_data),
  );

  @override
  Future<Map<String, String>?> initialOpened() async {
    final messaging = await _messaging();
    final message = await messaging?.getInitialMessage();
    return message == null ? null : _data(message);
  }

  @override
  Future<bool> isBlocked() async {
    try {
      final settings = await (await _messaging())?.getNotificationSettings();
      return settings?.authorizationStatus == AuthorizationStatus.denied;
    } on Object {
      return false;
    }
  }

  // Page de l'application dans les réglages du système (le plugin de position la fournit déjà).
  @override
  Future<void> openSettings() => Geolocator.openAppSettings();
}

final pushServiceProvider = Provider<PushService>((ref) {
  final options = DefaultFirebaseOptions.currentPlatform;
  return options == null ? const DisabledPushService() : FirebasePushService(options);
});
