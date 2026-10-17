import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/notifications_api.dart';
import '../data/push_service.dart';

/// Écran à ouvrir pour une notification touchée (identifiants seulement dans les données).
String? routeForPush(Map<String, String> data) => switch (data['type']) {
  'chat_message' when data['conversationId'] != null => AppRoutes.conversation(
    data['conversationId']!,
  ),
  'ride_cancelled' ||
  'ride_reminder' when data['rideId'] != null => AppRoutes.ride(data['rideId']!),
  'replacement_proposed' || 'proposals_ready' => AppRoutes.home,
  _ => null,
};

/// Jeton de l'appareil enregistré auprès du serveur, indépendant de la session : la
/// déconnexion le retire avant d'effacer les jetons d'accès.
class DeviceTokenStore {
  String? token;

  Future<void> unregister(NotificationsApi api) async {
    final current = token;
    if (current == null) return;
    token = null;
    try {
      await api.unregisterDevice(current);
    } on Object {
      // Le serveur oubliera le jeton quand FCM le signalera périmé.
    }
  }
}

final deviceTokenStoreProvider = Provider<DeviceTokenStore>((ref) => DeviceTokenStore());

/// Appareil enregistré pour le push pendant la session (cahier §11 : activé par défaut) ;
/// une notification touchée ouvre le bon écran.
class PushRegistration {
  PushRegistration(this._push, this._api, this._store, this._open);

  final PushService _push;
  final NotificationsApi _api;
  final DeviceTokenStore _store;
  final void Function(String route) _open;
  final List<StreamSubscription<Object>> _subs = [];

  Future<void> start() async {
    _subs
      ..add(_push.tokenRefresh.listen((t) => unawaited(_register(t))))
      ..add(_push.opened.listen(_handle));
    final initial = await _push.initialOpened();
    if (initial != null) _handle(initial);
    final token = await _push.token();
    if (token != null) await _register(token);
  }

  Future<void> _register(String token) async {
    try {
      await _api.registerDevice(token);
      _store.token = token;
    } on Object {
      // Nouvel essai au prochain lancement ou renouvellement du jeton.
    }
  }

  void _handle(Map<String, String> data) {
    final route = routeForPush(data);
    if (route != null) _open(route);
  }

  void dispose() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
  }
}

final pushRegistrationProvider = Provider<PushRegistration?>((ref) {
  final signedIn = ref.watch(sessionProvider.select((s) => s.value == SessionStatus.signedIn));
  if (!signedIn) return null;
  final registration = PushRegistration(
    ref.watch(pushServiceProvider),
    ref.watch(notificationsApiProvider),
    ref.watch(deviceTokenStoreProvider),
    (route) => ref.read(appRouterProvider).push(route),
  );
  unawaited(registration.start());
  ref.onDispose(registration.dispose);
  return registration;
});

/// Préférences de notification ; chaque changement est enregistré tout de suite.
class NotificationPreferencesController extends AsyncNotifier<NotificationPreferences> {
  @override
  Future<NotificationPreferences> build() => ref.watch(notificationsApiProvider).preferences();

  Future<void> save(NotificationPreferences prefs) async {
    final previous = state.value;
    state = AsyncData(prefs);
    try {
      state = AsyncData(await ref.read(notificationsApiProvider).setPreferences(prefs));
    } on Object {
      if (previous != null) state = AsyncData(previous);
      rethrow;
    }
  }
}

final notificationPreferencesProvider =
    AsyncNotifierProvider.autoDispose<NotificationPreferencesController, NotificationPreferences>(
      NotificationPreferencesController.new,
      retry: (retryCount, error) => null,
    );

/// Notifications refusées au niveau du téléphone : relu à chaque retour dans l'application.
final pushBlockedProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(pushServiceProvider).isBlocked(),
);
