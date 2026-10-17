/// Propositions de trajets (docs/api.md, « Propositions et recherche »).
enum Direction {
  toCampus('to_campus'),
  fromCampus('from_campus');

  const Direction(this.wire);
  final String wire;

  static Direction fromWire(String value) => values.firstWhere((d) => d.wire == value);
}

/// Personne vue avant acceptation mutuelle : jamais de nom de famille ni d'adresse.
class PublicPerson {
  const PublicPerson({
    required this.userId,
    required this.firstName,
    required this.reliabilityScore,
    required this.detourMinutes,
    required this.status,
    this.photoUrl,
  });

  factory PublicPerson.fromJson(Map<String, dynamic> json) => PublicPerson(
    userId: json['userId'] as String,
    firstName: json['firstName'] as String,
    photoUrl: json['photoUrl'] as String?,
    reliabilityScore: (json['reliabilityScore'] as num).toDouble(),
    detourMinutes: json['detourMinutes'] as int,
    status: json['status'] as String,
  );

  final String userId;
  final String firstName;
  final String? photoUrl;
  final double reliabilityScore;
  final int detourMinutes;
  final String status;

  /// Demande de place à laquelle le conducteur doit répondre.
  bool get isRequest => status == 'requested';

  /// Score affiché sur 5 (le serveur le donne entre 0 et 1).
  String get scoreOutOfFive => (reliabilityScore * 5).toStringAsFixed(1).replaceAll('.', ',');
}

enum ProposalState { proposed, requested, waiting, confirmed, cancelled }

class Proposal {
  const Proposal({
    required this.id,
    required this.day,
    required this.direction,
    required this.time,
    required this.isDriver,
    required this.myStatus,
    required this.rideStatus,
    required this.seatsTotal,
    required this.seatsTaken,
    required this.detourMinutes,
    required this.driver,
    required this.passengers,
  });

  factory Proposal.fromJson(Map<String, dynamic> json) => Proposal(
    id: json['id'] as String,
    day: DateTime.parse(json['day'] as String),
    direction: Direction.fromWire(json['direction'] as String),
    time: DateTime.parse(json['time'] as String),
    isDriver: json['role'] == 'driver',
    myStatus: json['myStatus'] as String,
    rideStatus: json['rideStatus'] as String,
    seatsTotal: json['seatsTotal'] as int,
    seatsTaken: json['seatsTaken'] as int,
    detourMinutes: json['detourMinutes'] as int,
    driver: json['driver'] == null
        ? null
        : PublicPerson.fromJson(json['driver'] as Map<String, dynamic>),
    passengers: [
      for (final p in json['passengers'] as List<dynamic>)
        PublicPerson.fromJson(p as Map<String, dynamic>),
    ],
  );

  final String id;
  final DateTime day;
  final Direction direction;
  final DateTime time;
  final bool isDriver;
  final String myStatus;
  final String rideStatus;
  final int seatsTotal;
  final int seatsTaken;
  final int detourMinutes;
  final PublicPerson? driver;
  final List<PublicPerson> passengers;

  int get seatsLeft => seatsTotal - seatsTaken;

  /// État affiché : confirmé à deux, en attente de l'autre, ou à décider.
  ProposalState get state => switch ((rideStatus, myStatus)) {
    ('cancelled', _) || (_, 'cancelled') => ProposalState.cancelled,
    // Voiture choisie par le passager : le conducteur doit accepter la demande.
    (_, 'requested') => ProposalState.requested,
    // Trajet commencé ou terminé : toujours confirmé (« Voir la carte »).
    ('confirmed' || 'in_progress' || 'completed', _) => ProposalState.confirmed,
    (_, 'accepted') => ProposalState.waiting,
    _ => ProposalState.proposed,
  };

  bool get canAnswer => myStatus == 'proposed' && state == ProposalState.proposed;
}

/// Voiture où l'on peut monter (« voir d'autres », recherche).
class JoinableRide {
  const JoinableRide({
    required this.rideId,
    required this.day,
    required this.direction,
    required this.time,
    required this.seatsLeft,
    required this.driver,
  });

  factory JoinableRide.fromJson(Map<String, dynamic> json) => JoinableRide(
    rideId: json['rideId'] as String,
    day: DateTime.parse(json['day'] as String),
    direction: Direction.fromWire(json['direction'] as String),
    time: DateTime.parse(json['time'] as String),
    seatsLeft: json['seatsLeft'] as int,
    driver: PublicPerson.fromJson(json['driver'] as Map<String, dynamic>),
  );

  final String rideId;
  final DateTime day;
  final Direction direction;
  final DateTime time;
  final int seatsLeft;
  final PublicPerson driver;
}

/// Semaine ISO 8601 (`AAAA-Www`) d'une date locale.
String isoWeekOf(DateTime date) {
  final day = DateTime.utc(date.year, date.month, date.day);
  final thursday = day.add(Duration(days: 4 - day.weekday));
  final firstThursdayYear = DateTime.utc(thursday.year, 1, 1);
  final week = (thursday.difference(firstThursdayYear).inDays ~/ 7) + 1;
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}
