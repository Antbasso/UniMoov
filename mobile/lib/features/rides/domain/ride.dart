import '../../proposals/domain/proposal.dart';

/// Trajet confirmé vu par un participant (docs/api.md, « Trajets ») : le serveur ne
/// renvoie que ce que ce participant a le droit de voir.
enum StopKind { driver, passenger, campus }

class RideStop {
  const RideStop({
    required this.order,
    required this.kind,
    required this.label,
    required this.lat,
    required this.lon,
    required this.isMeetingPoint,
    this.userId,
    this.firstName,
    this.lastName,
    this.eta,
  });

  factory RideStop.fromJson(Map<String, dynamic> json) => RideStop(
    order: json['order'] as int,
    kind: StopKind.values.byName(json['kind'] as String),
    userId: json['userId'] as String?,
    firstName: json['firstName'] as String?,
    lastName: json['lastName'] as String?,
    label: json['label'] as String,
    lat: (json['lat'] as num).toDouble(),
    lon: (json['lon'] as num).toDouble(),
    eta: json['eta'] == null ? null : DateTime.parse(json['eta'] as String),
    isMeetingPoint: json['isMeetingPoint'] as bool,
  );

  final int order;
  final StopKind kind;
  final String? userId;
  final String? firstName;

  /// Rempli seulement entre conducteur et passager acceptés.
  final String? lastName;
  final String label;
  final double lat;
  final double lon;
  final DateTime? eta;
  final bool isMeetingPoint;

  String? get fullName => firstName == null ? null : [firstName, ?lastName].join(' ');
}

/// Prix estimé, en centimes entiers (cahier §5).
class RidePrice {
  const RidePrice({
    required this.totalCostCents,
    required this.persons,
    required this.shareCents,
    required this.commissionCents,
    this.youPayCents,
    this.youReceiveCents,
  });

  factory RidePrice.fromJson(Map<String, dynamic> json) => RidePrice(
    totalCostCents: json['totalCostCents'] as int,
    persons: json['persons'] as int,
    shareCents: json['shareCents'] as int,
    commissionCents: json['commissionCents'] as int,
    youPayCents: json['youPayCents'] as int?,
    youReceiveCents: json['youReceiveCents'] as int?,
  );

  final int totalCostCents;
  final int persons;
  final int shareCents;
  final int commissionCents;
  final int? youPayCents;
  final int? youReceiveCents;
}

class RideDetails {
  const RideDetails({
    required this.id,
    required this.day,
    required this.direction,
    required this.time,
    required this.status,
    required this.isDriver,
    required this.routeEstimated,
    required this.route,
    required this.stops,
    this.distanceM,
    this.durationS,
    this.price,
  });

  factory RideDetails.fromJson(Map<String, dynamic> json) => RideDetails(
    id: json['id'] as String,
    day: DateTime.parse(json['day'] as String),
    direction: Direction.fromWire(json['direction'] as String),
    time: DateTime.parse(json['time'] as String),
    status: json['status'] as String,
    isDriver: json['role'] == 'driver',
    distanceM: json['distanceM'] as int?,
    durationS: json['durationS'] as int?,
    routeEstimated: json['routeEstimated'] as bool,
    route: [
      for (final point in json['route'] as List<dynamic>)
        (((point as List<dynamic>)[0] as num).toDouble(), (point[1] as num).toDouble()),
    ],
    stops: [
      for (final s in json['stops'] as List<dynamic>) RideStop.fromJson(s as Map<String, dynamic>),
    ],
    price: json['price'] == null ? null : RidePrice.fromJson(json['price'] as Map<String, dynamic>),
  );

  final String id;
  final DateTime day;
  final Direction direction;
  final DateTime time;
  final String status;
  final bool isDriver;
  final int? distanceM;
  final int? durationS;

  /// Tracé approximatif (lignes droites) quand le service d'itinéraires était indisponible.
  final bool routeEstimated;

  /// Tracé : couples (latitude, longitude) dans l'ordre du trajet.
  final List<(double, double)> route;
  final List<RideStop> stops;
  final RidePrice? price;

  /// Mon arrêt (passager), pour le point de rendez-vous.
  RideStop? stopOf(String? userId) => stops.where((s) => s.userId == userId).firstOrNull;

  bool get editable => status == 'confirmed';
}

/// Passager supplémentaire proposé au conducteur, avec la simulation du prix.
class Suggestion {
  const Suggestion({
    required this.person,
    required this.withinDetourLimit,
    required this.shareCents,
    required this.passengerPaysCents,
  });

  factory Suggestion.fromJson(Map<String, dynamic> json) => Suggestion(
    person: PublicPerson.fromJson(json['person'] as Map<String, dynamic>),
    withinDetourLimit: json['withinDetourLimit'] as bool,
    shareCents: json['shareCents'] as int,
    passengerPaysCents: json['passengerPaysCents'] as int,
  );

  final PublicPerson person;
  final bool withinDetourLimit;
  final int shareCents;
  final int passengerPaysCents;
}

class Suggestions {
  const Suggestions({required this.seatsLeft, required this.items, this.currentPassengerPaysCents});

  factory Suggestions.fromJson(Map<String, dynamic> json) => Suggestions(
    seatsLeft: json['seatsLeft'] as int,
    currentPassengerPaysCents: json['current'] == null
        ? null
        : (json['current'] as Map<String, dynamic>)['passengerPaysCents'] as int,
    items: [
      for (final s in json['suggestions'] as List<dynamic>)
        Suggestion.fromJson(s as Map<String, dynamic>),
    ],
  );

  final int seatsLeft;

  /// Prix actuel par passager, pour comparer avec la simulation.
  final int? currentPassengerPaysCents;
  final List<Suggestion> items;
}

/// Point de rendez-vous choisi par le passager (null : son adresse).
class MeetingPoint {
  const MeetingPoint({required this.label, required this.lat, required this.lon});

  final String label;
  final double lat;
  final double lon;
}
