import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/features/proposals/domain/proposal.dart';
import 'package:unimoov/features/schedule/domain/schedule.dart';

void main() {
  group('isoWeekOf', () {
    test('semaines ISO, y compris en début et fin d’année', () {
      expect(isoWeekOf(DateTime(2026, 10, 15)), '2026-W42');
      expect(isoWeekOf(DateTime(2026, 10, 19)), '2026-W43');
      expect(isoWeekOf(DateTime(2027, 1, 1)), '2026-W53');
      expect(isoWeekOf(DateTime(2025, 12, 29)), '2026-W01');
      expect(isoWeekOf(DateTime(2026, 10, 18, 23, 59)), '2026-W42'); // dimanche soir
    });
  });

  group('Proposal', () {
    Map<String, dynamic> json({
      String role = 'passenger',
      String my = 'proposed',
      String ride = 'proposed',
    }) => {
      'id': 'r1',
      'day': '2026-10-19',
      'direction': 'to_campus',
      'time': '2026-10-19T06:00:00.000Z',
      'role': role,
      'myStatus': my,
      'rideStatus': ride,
      'seatsTotal': 3,
      'seatsTaken': 1,
      'detourMinutes': 4,
      'driver': role == 'passenger'
          ? {
              'userId': 'd',
              'firstName': 'Léa',
              'photoUrl': null,
              'sector': {'lat': 45.9, 'lon': 6.1},
              'reliabilityScore': 0.84,
              'detourMinutes': 4,
              'status': 'proposed',
            }
          : null,
      'passengers': <dynamic>[],
    };

    test('lit une proposition de passager', () {
      final p = Proposal.fromJson(json());
      expect(p.isDriver, isFalse);
      expect(p.direction, Direction.toCampus);
      expect(p.driver!.firstName, 'Léa');
      expect(p.driver!.scoreOutOfFive, '4,2');
      expect(p.seatsLeft, 2);
    });

    test('état affiché', () {
      expect(Proposal.fromJson(json()).state, ProposalState.proposed);
      expect(Proposal.fromJson(json(my: 'accepted')).state, ProposalState.waiting);
      expect(
        Proposal.fromJson(json(my: 'accepted', ride: 'confirmed')).state,
        ProposalState.confirmed,
      );
      expect(Proposal.fromJson(json(ride: 'cancelled')).state, ProposalState.cancelled);
      expect(Proposal.fromJson(json(my: 'cancelled')).state, ProposalState.cancelled);
      expect(Proposal.fromJson(json()).canAnswer, isTrue);
      expect(Proposal.fromJson(json(my: 'accepted')).canAnswer, isFalse);
    });

    test('proposition de conducteur sans passager', () {
      final p = Proposal.fromJson(json(role: 'driver'));
      expect(p.isDriver, isTrue);
      expect(p.driver, isNull);
      expect(p.passengers, isEmpty);
    });
  });

  group('ManualDay', () {
    test('la fin doit suivre le début', () {
      expect(const ManualDay(weekday: 1, startTime: '08:00', endTime: '17:00').isValid, isTrue);
      expect(const ManualDay(weekday: 1, startTime: '17:00', endTime: '08:00').isValid, isFalse);
      expect(const ManualDay(weekday: 1, startTime: '08:00', endTime: '08:00').isValid, isFalse);
      expect(ManualDay.format(8, 5), '08:05');
    });
  });
}
