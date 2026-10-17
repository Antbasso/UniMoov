import 'dart:math';

import '../../proposals/domain/proposal.dart';

/// Monde fictif du mode démo : étudiants, campus et trajets autour d'Annecy. Aucune donnée
/// réelle ; les coordonnées sont des centres de communes.
class DemoPerson {
  const DemoPerson({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.label,
    required this.lat,
    required this.lon,
    required this.score,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String label;
  final double lat;
  final double lon;
  final double score;
}

const demoMeId = 'demo-me';
const demoEmail = 'camille.durand@etu.univ-smb.fr';
const demoPassword = 'unimoov-demo';
const demoCode = '123456';

const demoCampus = (label: "Campus d'Annecy (USMB)", lat: 45.9195, lon: 6.158);

const demoPeople = <String, DemoPerson>{
  'nathan': DemoPerson(
    id: 'nathan',
    firstName: 'Nathan',
    lastName: 'Petit',
    label: 'Centre, 74320 Sévrier',
    lat: 45.864,
    lon: 6.141,
    score: 0.9,
  ),
  'ines': DemoPerson(
    id: 'ines',
    firstName: 'Inès',
    lastName: 'Robert',
    label: 'Vieille ville, 74000 Annecy',
    lat: 45.8992,
    lon: 6.1294,
    score: 0.86,
  ),
  'hugo': DemoPerson(
    id: 'hugo',
    firstName: 'Hugo',
    lastName: 'Bernard',
    label: 'Centre, 74960 Cran-Gevrier',
    lat: 45.905,
    lon: 6.103,
    score: 0.8,
  ),
  'lea': DemoPerson(
    id: 'lea',
    firstName: 'Léa',
    lastName: 'Martin',
    label: 'Centre, 74960 Meythet',
    lat: 45.918,
    lon: 6.096,
    score: 0.94,
  ),
  'manon': DemoPerson(
    id: 'manon',
    firstName: 'Manon',
    lastName: 'Laurent',
    label: 'Centre, 74370 Argonay',
    lat: 45.942,
    lon: 6.142,
    score: 0.76,
  ),
  'lucas': DemoPerson(
    id: 'lucas',
    firstName: 'Lucas',
    lastName: 'Moreau',
    label: 'Centre, 74150 Rumilly',
    lat: 45.8667,
    lon: 5.944,
    score: 0.88,
  ),
  'theo': DemoPerson(
    id: 'theo',
    firstName: 'Théo',
    lastName: 'Simon',
    label: 'Centre, 74370 Pringy',
    lat: 45.948,
    lon: 6.123,
    score: 0.7,
  ),
};

/// Place d'une personne dans un trajet de démo.
class DemoSeat {
  DemoSeat(this.personId, this.status, {this.detourMinutes = 3});

  final String personId;

  /// proposed, requested, accepted, declined, cancelled.
  String status;
  final int detourMinutes;
  bool pickedUp = false;
  bool presenceValidated = false;
  bool arrived = false;
  bool ended = false;
  ({String label, double lat, double lon})? meetingPoint;

  /// Réponse automatique du conducteur ou du passager après ce moment (démo).
  DateTime? autoAcceptAt;

  bool get active => status == 'accepted';
}

/// Trajet de démo : une voiture, un sens, un jour ; propositions et trajet confirmé en dérivent.
class DemoRide {
  DemoRide({
    required this.id,
    required this.day,
    required this.direction,
    required this.time,
    required this.driverId,
    required this.driverStatus,
    required this.seats,
    this.status = 'proposed',
    this.seatsTotal = 3,
    this.consumption = 5.8,
  });

  final String id;
  final DateTime day;
  final Direction direction;
  final DateTime time;
  final String driverId;
  String driverStatus;
  final List<DemoSeat> seats;

  /// proposed, confirmed, in_progress, completed, cancelled.
  String status;
  final int seatsTotal;
  final double consumption;

  bool get driverIsMe => driverId == demoMeId;

  DemoSeat? seatOf(String personId) => seats.where((s) => s.personId == personId).firstOrNull;

  List<DemoSeat> get activeSeats => seats.where((s) => s.active).toList();
}

/// Distance à vol d'oiseau en mètres.
double demoDistance(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;
  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
  return 2 * r * asin(sqrt(a));
}

/// Coût du carburant en centimes (prix moyen fictif 1,85 €/L, facteur routier 1,3).
int demoCostCents(double meters, double consumption) =>
    (meters * 1.3 / 1000 * consumption / 100 * 185).round();

const demoCommissionCents = 20;
