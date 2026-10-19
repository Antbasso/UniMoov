import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/features/proposals/domain/proposal.dart';
import 'package:unimoov/features/rides/domain/ride.dart';

void main() {
  final json = {
    'id': 'r1',
    'day': '2026-10-19',
    'direction': 'from_campus',
    'time': '2026-10-19T15:00:00.000Z',
    'status': 'confirmed',
    'role': 'passenger',
    'seatsTotal': 3,
    'distanceM': 9000,
    'durationS': 900,
    'routeEstimated': true,
    'route': [
      [45.9195, 6.158],
      [45.9, 6.12],
    ],
    'stops': [
      {
        'order': 0,
        'kind': 'campus',
        'userId': null,
        'firstName': null,
        'lastName': null,
        'label': 'Campus',
        'lat': 45.9195,
        'lon': 6.158,
        'eta': '2026-10-19T15:00:00.000Z',
        'isMeetingPoint': false,
      },
      {
        'order': 1,
        'kind': 'passenger',
        'userId': 'u2',
        'firstName': 'Hugo',
        'lastName': null,
        'label': 'Arrêt Mairie',
        'lat': 45.9,
        'lon': 6.12,
        'eta': null,
        'isMeetingPoint': true,
      },
    ],
    'price': {
      'estimated': true,
      'totalCostCents': 94,
      'persons': 2,
      'shareCents': 47,
      'commissionCents': 20,
      'passengerPaysCents': 67,
      'driverReceivesCents': 47,
      'youPayCents': 67,
      'youReceiveCents': null,
    },
  };

  test('lit un trajet confirmé du serveur', () {
    final ride = RideDetails.fromJson(json);
    expect(ride.direction, Direction.fromCampus);
    expect(ride.isDriver, isFalse);
    expect(ride.routeEstimated, isTrue);
    expect(ride.route, [(45.9195, 6.158), (45.9, 6.12)]);
    expect(ride.stops.first.kind, StopKind.campus);
    expect(ride.stops.first.fullName, isNull);
    final hugo = ride.stopOf('u2')!;
    expect(hugo.fullName, 'Hugo'); // nom de famille non transmis : prénom seul
    expect(hugo.isMeetingPoint, isTrue);
    expect(hugo.eta, isNull);
    expect(ride.price!.youPayCents, 67);
    expect(ride.price!.youReceiveCents, isNull);
    expect(ride.editable, isTrue);
  });

  test('mon temps de trajet : ma portion pour un passager, tout pour le conducteur', () {
    final stops = [
      for (final stop in json['stops']! as List<dynamic>)
        {
          ...(stop as Map<String, dynamic>),
          if (stop['userId'] == 'u2') 'eta': '2026-10-19T15:22:00.000Z',
        },
    ];
    final ride = RideDetails.fromJson({...json, 'stops': stops});
    // Retour : du campus (15 h 00) à ma dépose (15 h 22).
    expect(ride.myDuration('u2'), const Duration(minutes: 22));
    // Heure de passage inconnue : rien plutôt qu'une durée fausse.
    expect(RideDetails.fromJson(json).myDuration('u2'), isNull);
    // Conducteur : tout l'itinéraire.
    final driving = RideDetails.fromJson({...json, 'role': 'driver'});
    expect(driving.myDuration('u1'), const Duration(minutes: 15));
  });

  test('sans prix (véhicule retiré) et trajet terminé : non modifiable', () {
    final ride = RideDetails.fromJson({...json, 'price': null, 'status': 'completed'});
    expect(ride.price, isNull);
    expect(ride.editable, isFalse);
  });

  test('lit les suggestions et le prix actuel', () {
    final s = Suggestions.fromJson({
      'seatsLeft': 2,
      'current': {'persons': 2, 'shareCents': 47, 'passengerPaysCents': 67},
      'suggestions': [
        {
          'person': {
            'userId': 'u3',
            'firstName': 'Théo',
            'photoUrl': null,
            'sector': {'lat': 45.95, 'lon': 6.12},
            'reliabilityScore': 0.8,
            'detourMinutes': 14,
            'status': 'suggested',
          },
          'withinDetourLimit': false,
          'shareCents': 40,
          'passengerPaysCents': 60,
        },
      ],
    });
    expect(s.seatsLeft, 2);
    expect(s.currentPassengerPaysCents, 67);
    expect(s.items.single.person.firstName, 'Théo');
    expect(s.items.single.withinDetourLimit, isFalse);
    expect(
      Suggestions.fromJson({'seatsLeft': 0, 'current': null, 'suggestions': []})
          .currentPassengerPaysCents,
      isNull,
    );
  });
}
