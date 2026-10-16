import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/core/location/location_service.dart';
import 'package:unimoov/features/rides/data/live_channel.dart';
import 'package:unimoov/features/rides/data/rides_api.dart';
import 'package:unimoov/features/rides/domain/ride.dart';
import 'package:unimoov/features/rides/presentation/live_controller.dart';

import '../../support/fake_backend.dart';
import '../../support/live_fakes.dart';

void main() {
  late FakeLiveConnector connector;
  late FakeLocationService location;
  late ProviderContainer container;

  setUp(() {
    connector = FakeLiveConnector();
    location = FakeLocationService();
    final backend = rideBackend();
    container = ProviderContainer(
      overrides: [
        liveConnectorProvider.overrideWithValue(connector),
        locationServiceProvider.overrideWithValue(location),
        ridesApiProvider.overrideWithValue(backend),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('positions, heures d’arrivée, montée et présence mettent l’état à jour', () async {
    final sub = container.listen(liveRideProvider('ride-1'), (_, _) {});
    addTearDown(sub.close);
    await settle();
    final c = connector.last;
    c.emit(const LiveReady());
    c.emit(
      LivePosition(userId: 'driver-1', lat: 45.9, lon: 6.12, at: DateTime.utc(2026, 10, 19, 5, 45)),
    );
    c.emit(LiveEta(userId: 'me', eta: DateTime.utc(2026, 10, 19, 5, 50)));
    c.emit(const LivePickedUp('passenger-3'));
    c.emit(const LivePresence(userId: 'me', paid: true));
    await settle();
    final state = container.read(liveRideProvider('ride-1'));
    expect(state.connected, isTrue);
    expect(state.positions['driver-1']!.lat, 45.9);
    expect(state.etas['me'], DateTime.utc(2026, 10, 19, 5, 50));
    expect(state.pickedUp, {'passenger-3'});
    expect(state.presence, {'me': true});
  });

  test('coupure réseau : reconnexion ; clôture (4410) : arrêt définitif', () async {
    final sub = container.listen(liveRideProvider('ride-1'), (_, _) {});
    addTearDown(sub.close);
    await settle();
    connector.last.serverClose(1006);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(connector.connections, hasLength(2));
    connector.last.serverClose(4410);
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    expect(connector.connections, hasLength(2));
    expect(container.read(liveRideProvider('ride-1')).ended, isTrue);
  });

  test('ma position n’est envoyée qu’avec la permission, et s’arrête à la fermeture', () async {
    final sub = container.listen(liveRideProvider('ride-1'), (_, _) {});
    addTearDown(sub.close);
    await settle();
    final notifier = container.read(liveRideProvider('ride-1').notifier);
    await notifier.startSharing(notificationTitle: 't', notificationText: 'x');
    expect(container.read(liveRideProvider('ride-1')).sharing, isFalse);

    location.access = LocationAccess.granted;
    await notifier.startSharing(notificationTitle: 't', notificationText: 'x');
    location.positionsController.add((lat: 45.9, lon: 6.12, at: DateTime.utc(2026)));
    await settle();
    expect(connector.last.sent, [(lat: 45.9, lon: 6.12)]);

    sub.close();
    container.invalidate(liveRideProvider('ride-1'));
    await settle();
    expect(connector.last.closedByClient, isTrue);
  });
}
