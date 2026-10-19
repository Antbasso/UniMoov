import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../data/live_channel.dart';
import '../data/rides_api.dart';
import '../domain/ride.dart';
import 'rides_controller.dart';

/// État du suivi en direct d'un trajet en cours.
class LiveState {
  const LiveState({
    this.connected = false,
    this.positions = const {},
    this.etas = const {},
    this.pickedUp = const {},
    this.sharing = false,
    this.ended = false,
  });

  final bool connected;

  /// Dernière position reçue par personne (le conducteur pour un passager, les passagers
  /// pas encore montés pour le conducteur).
  final Map<String, LivePosition> positions;
  final Map<String, DateTime> etas;
  final Set<String> pickedUp;

  /// Ma position est envoyée (permission accordée, trajet en cours).
  final bool sharing;

  /// Trajet clôturé : plus rien n'est diffusé.
  final bool ended;

  LiveState copyWith({
    bool? connected,
    Map<String, LivePosition>? positions,
    Map<String, DateTime>? etas,
    Set<String>? pickedUp,
    bool? sharing,
    bool? ended,
  }) => LiveState(
    connected: connected ?? this.connected,
    positions: positions ?? this.positions,
    etas: etas ?? this.etas,
    pickedUp: pickedUp ?? this.pickedUp,
    sharing: sharing ?? this.sharing,
    ended: ended ?? this.ended,
  );
}

/// Après 30 s sans nouvelle position : « dernière position connue » (architecture §6).
const staleAfter = Duration(seconds: 30);

/// Immobile, le téléphone n'envoie plus rien : la dernière position est renvoyée à ce rythme,
/// pour que la présence puisse être validée quand le conducteur arrive (20 s, docs/couts.md).
const heartbeat = Duration(seconds: 20);

/// Suivi en direct (WebSocket) et envoi de ma position pendant le trajet. Reconnexion avec
/// délai croissant ; arrêt définitif à la clôture ou si l'accès est refusé.
class LiveRideController extends Notifier<LiveState> {
  LiveRideController(this.rideId);

  final String rideId;
  LiveConnection? _connection;
  StreamSubscription<LiveEvent>? _events;
  StreamSubscription<GeoPoint>? _positions;
  Timer? _retry;
  Timer? _heartbeat;
  GeoPoint? _lastFix;
  int _attempt = 0;
  bool _disposed = false;

  @override
  LiveState build() {
    ref.onDispose(_stop);
    unawaited(_connect());
    return const LiveState();
  }

  Future<void> _connect() async {
    if (_disposed) return;
    try {
      // Appel authentifié d'abord : le jeton d'accès (15 min) est renouvelé s'il a expiré.
      await ref.read(ridesApiProvider).ride(rideId);
      if (_disposed) return;
      final connection = await ref.read(liveConnectorProvider).connect(rideId);
      if (_disposed) {
        await connection.close();
        return;
      }
      _connection = connection;
      // Trame illisible ou connexion coupée : traitées comme une fermeture, jamais remontées.
      _events = connection.events.listen(
        _onEvent,
        onError: (Object _) => unawaited(connection.close()),
      );
      unawaited(connection.closeCode.then(_onClosed, onError: (Object _) => _onClosed(null)));
    } on Object {
      _scheduleRetry();
    }
  }

  void _onEvent(LiveEvent event) {
    if (_disposed) return;
    switch (event) {
      case LiveReady():
        _attempt = 0;
        state = state.copyWith(connected: true);
      case LivePosition():
        state = state.copyWith(positions: {...state.positions, event.userId: event});
      case LiveEta():
        state = state.copyWith(etas: {...state.etas, event.userId: event.eta});
      case LivePickedUp():
        state = state.copyWith(pickedUp: {...state.pickedUp, event.userId});
        ref.invalidate(rideProvider(rideId));
      case LivePresence() || LivePassengerDone():
        ref.invalidate(rideProvider(rideId));
        ref.invalidate(navigationProvider(rideId));
      case LiveStatus(:final status):
        if (status == 'completed') {
          state = state.copyWith(ended: true, connected: false);
          ref.invalidate(rideProvider(rideId));
        }
    }
  }

  void _onClosed(int? code) {
    if (_disposed) return;
    unawaited(_events?.cancel());
    _connection = null;
    state = state.copyWith(connected: false);
    if (code != null && liveFinalCodes.contains(code)) {
      unawaited(_positions?.cancel());
      _positions = null;
      _heartbeat?.cancel();
      state = state.copyWith(sharing: false, ended: code == 4410 || state.ended);
      return;
    }
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_disposed || state.ended) return;
    // 1 s, 2 s, 4 s… plafonné à 30 s.
    final delay = Duration(seconds: min(30, 1 << min(_attempt, 5)));
    _attempt++;
    _retry = Timer(delay, () => unawaited(_connect()));
  }

  /// Partage de ma position (après l'écran d'explication et la permission système).
  Future<void> startSharing({
    required String notificationTitle,
    required String notificationText,
  }) async {
    if (_positions != null || state.ended) return;
    final location = ref.read(locationServiceProvider);
    if (await location.status() != LocationAccess.granted) return;
    _positions = location
        .positions(notificationTitle: notificationTitle, notificationText: notificationText)
        .listen(
          (p) {
            _lastFix = p;
            _connection?.sendPosition(lat: p.lat, lon: p.lon, at: p.at);
          },
          // GPS coupé ou permission retirée : on cesse de partager plutôt que d'envoyer du vieux.
          onError: (Object _) => _stopSharing(),
        );
    _heartbeat = Timer.periodic(heartbeat, (_) {
      final fix = _lastFix;
      // Immobile, le GPS (filtre de distance) n'envoie plus rien : la dernière position est
      // renvoyée avec son heure d'origine. GPS coupé : l'erreur du flux arrête le partage.
      if (fix != null) {
        _connection?.sendPosition(lat: fix.lat, lon: fix.lon, at: fix.at);
      }
    });
    state = state.copyWith(sharing: true);
  }

  void _stopSharing() {
    _heartbeat?.cancel();
    _heartbeat = null;
    unawaited(_positions?.cancel());
    _positions = null;
    _lastFix = null;
    if (!_disposed) state = state.copyWith(sharing: false);
  }

  void _stop() {
    _disposed = true;
    _retry?.cancel();
    _heartbeat?.cancel();
    unawaited(_events?.cancel());
    unawaited(_positions?.cancel());
    unawaited(_connection?.close());
  }
}

final liveRideProvider = NotifierProvider.autoDispose.family<LiveRideController, LiveState, String>(
  LiveRideController.new,
);
