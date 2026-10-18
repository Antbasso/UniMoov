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

/// Profil visible des étudiants fictifs : formation, âge, centres d'intérêt.
const demoAbout = <String, ({String study, int age, List<String> interests})>{
  'nathan': (study: 'BUT Génie mécanique', age: 20, interests: ['Ski', 'Rock']),
  'ines': (study: 'Licence Droit', age: 19, interests: ['Théâtre', 'Randonnée']),
  'hugo': (study: 'BUT Informatique', age: 21, interests: ['Jeux vidéo', 'Escalade']),
  'lea': (study: 'Master Management', age: 23, interests: ['Course à pied', 'Cuisine']),
  'manon': (study: 'BUT Techniques de commercialisation', age: 20, interests: ['Danse']),
  'lucas': (study: 'Licence Mathématiques', age: 22, interests: ['Échecs', 'Vélo']),
  'theo': (study: 'BUT Mesures physiques', age: 19, interests: ['Football']),
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

/// Lieux des tracés précalculés (`demo_routes.g.dart`) : domicile de chaque personne, Camille
/// à Seynod, le campus. Un nouveau compte de démo habite au centre d'Annecy (même point qu'Inès).
const demoPlaces = <String, (double, double)>{
  'campus': (45.9195, 6.158),
  'camille': (45.8865, 6.089),
  'nathan': (45.864, 6.141),
  'ines': (45.8992, 6.1294),
  'hugo': (45.905, 6.103),
  'lea': (45.918, 6.096),
  'manon': (45.942, 6.142),
  'lucas': (45.8667, 5.944),
  'theo': (45.948, 6.123),
};

/// Décode une polyligne encodée (algorithme de Google, précision 1e-5).
List<(double, double)> decodePolyline(String encoded) {
  final points = <(double, double)>[];
  var index = 0;
  var lat = 0;
  var lon = 0;
  int next() {
    var shift = 0;
    var result = 0;
    int byte;
    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
  }

  while (index < encoded.length) {
    lat += next();
    lon += next();
    points.add((lat / 1e5, lon / 1e5));
  }
  return points;
}

/// Adresses fictives proposées pendant la saisie (démo) : chacune tombe sur un lieu des tracés
/// précalculés.
const demoAddresses = <(String, double, double)>[
  ('12 Rue de la Paix 74000 Annecy', 45.8992, 6.1294),
  ('1 Place de l’Hôtel de Ville 74600 Annecy', 45.8865, 6.089),
  ('8 Avenue de Cran 74960 Annecy', 45.905, 6.103),
  ('15 Route de Frangy 74960 Annecy', 45.918, 6.096),
  ('4 Rue du Pré Paillard 74370 Annecy', 45.942, 6.142),
];

/// Minuscules, sans accents ni ponctuation : comparaison tolérante d'une saisie.
String demoNormalize(String text) {
  const from = 'àâäéèêëîïôöùûüç’\'';
  const to = 'aaaeeeeiioouuuc  ';
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    buffer.write(i >= 0 ? to[i] : ch);
  }
  return buffer
      .toString()
      .replaceAll(RegExp('[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Partage au prorata de la distance, comme le serveur (cahier §5) : chaque portion de route est
/// partagée entre les personnes à bord, conducteur compris. `onboardM` : distance à bord de
/// chaque passager, mesurée depuis le campus. Parts en centimes, arrondies au centime supérieur.
List<int> demoProRataShares(int costCents, double distanceM, List<double> onboardM) {
  if (distanceM <= 0) return [for (final _ in onboardM) 0];
  final perMeter = costCents / distanceM;
  final onboard = [for (final d in onboardM) d.clamp(0, distanceM).toDouble()];
  final cuts = {0.0, ...onboard}.toList()..sort();
  final shares = List<double>.filled(onboard.length, 0);
  for (var k = 1; k < cuts.length; k++) {
    final aboard = [
      for (var i = 0; i < onboard.length; i++)
        if (onboard[i] >= cuts[k]) i,
    ];
    final each = (cuts[k] - cuts[k - 1]) * perMeter / (aboard.length + 1);
    for (final i in aboard) {
      shares[i] += each;
    }
  }
  return [for (final v in shares) max(0, (v - 1e-9).ceil())];
}

/// Portions de route depuis le campus : longueur et indices des passagers à bord (comme le
/// serveur), pour le détail du calcul.
List<({double distance, List<int> riders})> demoPortions(double distanceM, List<double> onboardM) {
  final onboard = [for (final d in onboardM) d.clamp(0, distanceM).toDouble()];
  final cuts = {0.0, ...onboard}.toList()..sort();
  final portions = <({double distance, List<int> riders})>[
    for (var k = 1; k < cuts.length; k++)
      (
        distance: cuts[k] - cuts[k - 1],
        riders: [
          for (var i = 0; i < onboard.length; i++)
            if (onboard[i] >= cuts[k]) i,
        ],
      ),
  ];
  if (distanceM - cuts.last > 0) portions.add((distance: distanceM - cuts.last, riders: const []));
  return portions;
}
