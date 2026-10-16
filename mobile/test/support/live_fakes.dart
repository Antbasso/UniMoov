import 'dart:async';

import 'package:unimoov/core/location/location_service.dart';
import 'package:unimoov/features/rides/data/live_channel.dart';
import 'package:unimoov/features/rides/data/nav_launcher.dart';
import 'package:unimoov/features/rides/domain/ride.dart';

/// Faux serveur de suivi : les tests poussent des événements et ferment avec un code.
class FakeLiveConnector implements LiveConnector {
  final List<FakeLiveConnection> connections = [];
  bool fail = false;

  FakeLiveConnection get last => connections.last;

  @override
  Future<LiveConnection> connect(String rideId) async {
    if (fail) throw StateError('hors ligne');
    final connection = FakeLiveConnection();
    connections.add(connection);
    return connection;
  }
}

class FakeLiveConnection implements LiveConnection {
  final _events = StreamController<LiveEvent>.broadcast();
  final _closed = Completer<int?>();
  final List<({double lat, double lon})> sent = [];
  bool closedByClient = false;

  void emit(LiveEvent event) => _events.add(event);

  void serverClose(int code) {
    if (!_closed.isCompleted) _closed.complete(code);
  }

  @override
  Stream<LiveEvent> get events => _events.stream;

  @override
  Future<int?> get closeCode => _closed.future;

  @override
  void sendPosition({required double lat, required double lon, required DateTime at}) =>
      sent.add((lat: lat, lon: lon));

  @override
  Future<void> close() async {
    closedByClient = true;
    if (!_closed.isCompleted) _closed.complete(null);
    await _events.close();
  }
}

class FakeLocationService implements LocationService {
  LocationAccess access = LocationAccess.denied;
  LocationAccess onRequest = LocationAccess.granted;
  final positionsController = StreamController<GeoPoint>.broadcast();
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<LocationAccess> status() async => access;

  @override
  Future<LocationAccess> request() async {
    requests++;
    return access = onRequest;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;

  @override
  Stream<GeoPoint> positions({
    required String notificationTitle,
    required String notificationText,
  }) => positionsController.stream;
}

class FakeNavLauncher implements NavLauncher {
  List<NavApp> apps = [NavApp.googleMaps, NavApp.waze];
  final List<Uri> opened = [];
  bool succeed = true;

  @override
  Future<List<NavApp>> installed() async => apps;

  @override
  Future<bool> open(Uri link) async {
    opened.add(link);
    return succeed;
  }
}
