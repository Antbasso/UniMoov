import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/features/rides/domain/ride.dart';

void main() {
  final plan = NavigationPlan.fromJson({
    'stops': [
      {
        'order': 1,
        'kind': 'passenger',
        'userId': 'u1',
        'firstName': 'Hugo',
        'label': 'A',
        'lat': 45.9,
        'lon': 6.1,
        'eta': null,
        'pickedUp': true,
      },
      {
        'order': 2,
        'kind': 'passenger',
        'userId': 'u2',
        'firstName': 'Inès',
        'label': 'B',
        'lat': 45.8,
        'lon': 6.12,
        'eta': '2026-10-19T05:50:00.000Z',
        'pickedUp': false,
      },
      {
        'order': 3,
        'kind': 'destination',
        'userId': null,
        'firstName': null,
        'label': 'Campus',
        'lat': 45.91,
        'lon': 6.15,
        'eta': null,
        'pickedUp': false,
      },
    ],
    'links': {
      'googleMaps':
          'https://www.google.com/maps/dir/?api=1&destination=1,1&waypoints=2,2&travelmode=driving',
      'appleMaps': 'https://maps.apple.com/?daddr=2,2+to:1,1&dirflg=d',
      'waze': {'nextStop': 'https://waze.com/ul?ll=2,2&navigate=yes'},
    },
    'supportsMultiStop': {'googleMaps': true, 'appleMaps': true, 'waze': false},
  });

  test('lien selon l’application : Waze vers l’arrêt suivant seulement', () {
    expect(plan.linkFor(NavApp.googleMaps).host, 'www.google.com');
    expect(plan.linkFor(NavApp.appleMaps).host, 'maps.apple.com');
    expect(plan.linkFor(NavApp.waze).toString(), contains('ll=2,2'));
    expect(NavApp.waze.multiStop, isFalse);
    expect(NavApp.googleMaps.multiStop, isTrue);
  });

  test('arrêts restants : sans ceux déjà montés', () {
    expect(plan.remaining.map((s) => s.firstName), ['Inès', null]);
    expect(plan.stops.last.isDestination, isTrue);
  });

  test('application mémorisée lue depuis l’API', () {
    expect(NavApp.fromWire('waze'), NavApp.waze);
    expect(NavApp.fromWire(null), isNull);
    expect(NavApp.fromWire('inconnue'), isNull);
  });

  test('événements du suivi : types connus, les autres ignorés', () {
    expect(LiveEvent.fromJson({'type': 'ready', 'role': 'driver'}), isA<LiveReady>());
    final p =
        LiveEvent.fromJson({
              'type': 'position',
              'userId': 'd',
              'lat': 45,
              'lon': 6,
              'ts': '2026-10-19T05:45:00.000Z',
            })!
            as LivePosition;
    expect((p.lat, p.lon), (45.0, 6.0));
    expect(
      (LiveEvent.fromJson({'type': 'presence_validated', 'userId': 'u', 'payment': 'failed'})!
              as LivePresence)
          .paid,
      isFalse,
    );
    expect(
      (LiveEvent.fromJson({'type': 'ride_status', 'status': 'completed'})! as LiveStatus).status,
      'completed',
    );
    expect(LiveEvent.fromJson({'type': 'autre'}), isNull);
  });
}
