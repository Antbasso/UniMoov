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
    this.approximate = false,
    this.pickedUp = false,
    this.presenceValidated = false,
    this.arrived = false,
    this.ended = false,
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
    approximate: json['approximate'] as bool? ?? false,
    pickedUp: json['pickedUp'] as bool? ?? false,
    presenceValidated: json['presenceValidated'] as bool? ?? false,
    arrived: json['arrived'] as bool? ?? false,
    ended: json['ended'] as bool? ?? false,
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

  /// Centre du secteur, pas l'adresse : montré comme une zone (domicile d'un autre passager,
  /// départ du conducteur vu par un passager).
  final bool approximate;

  /// Passager monté (signalé par le conducteur) ; présence validée par proximité.
  final bool pickedUp;
  final bool presenceValidated;

  /// Passager arrivé à destination (il paiera à la clôture) ; trajet terminé pour lui,
  /// arrivé ou parti avant l'arrivée (il ne paie pas).
  final bool arrived;
  final bool ended;

  bool get leftEarly => ended && !arrived;

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
    this.myDistanceM,
    this.breakdown,
  });

  factory RidePrice.fromJson(Map<String, dynamic> json) => RidePrice(
    totalCostCents: json['totalCostCents'] as int,
    persons: json['persons'] as int,
    shareCents: json['shareCents'] as int,
    commissionCents: json['commissionCents'] as int,
    youPayCents: json['youPayCents'] as int?,
    youReceiveCents: json['youReceiveCents'] as int?,
    myDistanceM: json['myDistanceM'] as int?,
    breakdown: json['breakdown'] == null
        ? null
        : PriceBreakdown.fromJson(json['breakdown'] as Map<String, dynamic>),
  );

  final int totalCostCents;
  final int persons;
  final int shareCents;
  final int commissionCents;
  final int? youPayCents;
  final int? youReceiveCents;

  /// Passager : distance parcourue à bord (de sa prise en charge au campus, ou l'inverse) ;
  /// sa part du carburant est au prorata (cahier §5).
  final int? myDistanceM;

  /// Détail précis du calcul (consommation, prix du litre, portions, parts).
  final PriceBreakdown? breakdown;
}

/// Détail du calcul du prix (docs/api.md) : de quoi refaire le calcul à la main.
class PriceBreakdown {
  const PriceBreakdown({
    required this.consumptionLPer100km,
    required this.fuelPriceCentsPerLitre,
    required this.distanceM,
    required this.portions,
    this.shares = const [],
  });

  factory PriceBreakdown.fromJson(Map<String, dynamic> json) => PriceBreakdown(
    consumptionLPer100km: (json['consumptionLPer100km'] as num).toDouble(),
    fuelPriceCentsPerLitre: (json['fuelPriceCentsPerLitre'] as num).toDouble(),
    distanceM: json['distanceM'] as int,
    portions: [
      for (final p in json['portions'] as List<dynamic>)
        (distanceM: (p as Map<String, dynamic>)['distanceM'] as int, persons: p['persons'] as int),
    ],
    shares: [
      for (final s in json['shares'] as List<dynamic>)
        (
          firstName: (s as Map<String, dynamic>)['firstName'] as String,
          shareCents: s['shareCents'] as int,
        ),
    ],
  );

  final double consumptionLPer100km;
  final double fuelPriceCentsPerLitre;
  final int distanceM;

  /// Passager : ses portions ; conducteur : toutes. `persons` : conducteur compris.
  final List<({int distanceM, int persons})> portions;

  /// Conducteur : ce que paie chaque passager (sa part, hors frais de service).
  final List<({String firstName, int shareCents})> shares;

  double get litres => distanceM / 1000 * consumptionLPer100km / 100;
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
    this.myStatus = 'accepted',
    this.distanceM,
    this.durationS,
    this.price,
    this.vehicle,
  });

  factory RideDetails.fromJson(Map<String, dynamic> json) => RideDetails(
    id: json['id'] as String,
    day: DateTime.parse(json['day'] as String),
    direction: Direction.fromWire(json['direction'] as String),
    time: DateTime.parse(json['time'] as String),
    status: json['status'] as String,
    isDriver: json['role'] == 'driver',
    myStatus: json['myStatus'] as String? ?? 'accepted',
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
    vehicle: switch (json['vehicle']) {
      {'model': final String? model, 'color': final String? color} => (model: model, color: color),
      _ => null,
    },
  );

  final String id;
  final DateTime day;
  final Direction direction;
  final DateTime time;
  final String status;
  final bool isDriver;

  /// Mon statut sur ce trajet : `absent` après une clôture sans validation de présence.
  final String myStatus;
  final int? distanceM;
  final int? durationS;

  /// Tracé approximatif (lignes droites) quand le service d'itinéraires était indisponible.
  final bool routeEstimated;

  /// Tracé : couples (latitude, longitude) dans l'ordre du trajet.
  final List<(double, double)> route;
  final List<RideStop> stops;
  final RidePrice? price;

  /// Voiture du conducteur (modèle, couleur), pour la reconnaître au point de rendez-vous.
  final ({String? model, String? color})? vehicle;

  /// « Renault Clio grise », ou null si le conducteur n'a rien indiqué.
  String? get vehicleLabel {
    final parts = [?vehicle?.model, ?vehicle?.color].where((p) => p.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' ');
  }

  /// Mon arrêt (passager), pour le point de rendez-vous.
  RideStop? stopOf(String? userId) => stops.where((s) => s.userId == userId).firstOrNull;

  bool get editable => status == 'confirmed';
  bool get inProgress => status == 'in_progress';
  bool get completed => status == 'completed';
  bool get markedAbsent => myStatus == 'absent';

  /// Mon temps de trajet : tout l'itinéraire pour le conducteur ; pour un passager, de sa prise
  /// en charge au campus (aller) ou du campus à sa dépose (retour), d'après les heures de passage.
  Duration? myDuration(String? userId) {
    final mine = stopOf(userId);
    if (isDriver || mine == null || mine.kind != StopKind.passenger) {
      return durationS == null ? null : Duration(seconds: durationS!);
    }
    final campus = stops.where((s) => s.kind == StopKind.campus).firstOrNull?.eta;
    final (from, to) = direction == Direction.toCampus ? (mine.eta, campus) : (campus, mine.eta);
    if (from == null || to == null || to.isBefore(from)) return null;
    return to.difference(from);
  }

  /// Arrêt du conducteur (départ à l'aller, arrivée au retour).
  RideStop? get driverStop => stops.where((s) => s.kind == StopKind.driver).firstOrNull;
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

/// Applications GPS proposées au conducteur (cahier §15). `wire` : valeur de l'API.
enum NavApp {
  googleMaps('google_maps'),
  waze('waze'),
  appleMaps('apple_maps');

  const NavApp(this.wire);
  final String wire;

  static NavApp? fromWire(String? value) => values.where((a) => a.wire == value).firstOrNull;

  /// Waze n'accepte qu'une destination : navigation arrêt par arrêt.
  bool get multiStop => this != NavApp.waze;
}

/// Arrêts restants dans l'ordre et liens prêts à ouvrir (`GET /rides/{id}/navigation`).
class NavigationPlan {
  const NavigationPlan({
    required this.stops,
    required this.googleMaps,
    required this.appleMaps,
    required this.wazeNextStop,
  });

  factory NavigationPlan.fromJson(Map<String, dynamic> json) {
    final links = json['links'] as Map<String, dynamic>;
    return NavigationPlan(
      stops: [
        for (final s in json['stops'] as List<dynamic>)
          NavigationStop.fromJson(s as Map<String, dynamic>),
      ],
      googleMaps: links['googleMaps'] as String,
      appleMaps: links['appleMaps'] as String,
      wazeNextStop: (links['waze'] as Map<String, dynamic>)['nextStop'] as String,
    );
  }

  final List<NavigationStop> stops;
  final String googleMaps;
  final String appleMaps;
  final String wazeNextStop;

  /// Lien pour l'application choisie (Waze : l'arrêt suivant seulement), ou `null` s'il ne
  /// pointe pas vers l'application attendue : un lien venu du serveur n'ouvre jamais autre chose.
  Uri? linkFor(NavApp app) {
    final uri = Uri.tryParse(switch (app) {
      NavApp.googleMaps => googleMaps,
      NavApp.appleMaps => appleMaps,
      NavApp.waze => wazeNextStop,
    });
    final expected = switch (app) {
      NavApp.googleMaps => (host: 'www.google.com', path: '/maps/'),
      NavApp.appleMaps => (host: 'maps.apple.com', path: '/'),
      NavApp.waze => (host: 'waze.com', path: '/ul'),
    };
    if (uri == null || uri.scheme != 'https' || uri.host != expected.host) return null;
    if (!uri.path.startsWith(expected.path) || uri.userInfo.isNotEmpty || uri.hasPort) return null;
    return uri;
  }

  List<NavigationStop> get remaining => stops.where((s) => !s.pickedUp).toList();
}

class NavigationStop {
  const NavigationStop({
    required this.order,
    required this.isDestination,
    required this.label,
    required this.pickedUp,
    this.userId,
    this.firstName,
    this.eta,
  });

  factory NavigationStop.fromJson(Map<String, dynamic> json) => NavigationStop(
    order: json['order'] as int,
    isDestination: json['kind'] == 'destination',
    userId: json['userId'] as String?,
    firstName: json['firstName'] as String?,
    label: json['label'] as String,
    eta: json['eta'] == null ? null : DateTime.parse(json['eta'] as String),
    pickedUp: json['pickedUp'] as bool,
  );

  final int order;
  final bool isDestination;
  final String? userId;
  final String? firstName;
  final String label;
  final DateTime? eta;
  final bool pickedUp;
}

/// Messages du suivi en direct (docs/api.md, WebSocket).
sealed class LiveEvent {
  const LiveEvent();

  static LiveEvent? fromJson(Map<String, dynamic> json) => switch (json['type']) {
    'ready' => const LiveReady(),
    'position' => LivePosition(
      userId: json['userId'] as String,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      at: DateTime.parse(json['ts'] as String),
    ),
    'eta' => LiveEta(userId: json['userId'] as String, eta: DateTime.parse(json['eta'] as String)),
    'stop_picked_up' => LivePickedUp(json['userId'] as String),
    'presence_validated' => LivePresence(json['userId'] as String),
    'passenger_arrived' => LivePassengerDone(json['userId'] as String, arrived: true),
    'passenger_left' => LivePassengerDone(json['userId'] as String, arrived: false),
    'ride_status' => LiveStatus(json['status'] as String),
    _ => null,
  };
}

class LiveReady extends LiveEvent {
  const LiveReady();
}

class LivePosition extends LiveEvent {
  const LivePosition({
    required this.userId,
    required this.lat,
    required this.lon,
    required this.at,
  });

  final String userId;
  final double lat;
  final double lon;
  final DateTime at;
}

class LiveEta extends LiveEvent {
  const LiveEta({required this.userId, required this.eta});

  final String userId;
  final DateTime eta;
}

class LivePickedUp extends LiveEvent {
  const LivePickedUp(this.userId);

  final String userId;
}

class LivePresence extends LiveEvent {
  const LivePresence(this.userId);

  final String userId;
}

/// Trajet terminé pour un passager : arrivé à destination, ou parti avant (conducteur prévenu).
class LivePassengerDone extends LiveEvent {
  const LivePassengerDone(this.userId, {required this.arrived});

  final String userId;
  final bool arrived;
}

class LiveStatus extends LiveEvent {
  const LiveStatus(this.status);

  final String status;
}

/// Trajet terminé, dans l'historique du profil (`GET /rides/history`).
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.day,
    required this.direction,
    required this.time,
    required this.isDriver,
    required this.myStatus,
    required this.withNames,
    this.amountCents,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    id: json['id'] as String,
    day: DateTime.parse(json['day'] as String),
    direction: Direction.fromWire(json['direction'] as String),
    time: DateTime.parse(json['time'] as String),
    isDriver: json['role'] == 'driver',
    myStatus: json['myStatus'] as String,
    amountCents: json['amountCents'] as int?,
    withNames: [for (final n in json['with'] as List<dynamic>) n as String],
  );

  final String id;
  final DateTime day;
  final Direction direction;
  final DateTime time;
  final bool isDriver;
  final String myStatus;

  /// Payé (passager) ou reçu (conducteur) ; null sans paiement.
  final int? amountCents;
  final List<String> withNames;

  bool get absent => myStatus == 'absent';
}

/// Aperçu d'un trajet avant confirmation (`GET /rides/{id}/preview`) : tracé du conducteur sans
/// les abords des domiciles des autres, campus, et mon point (le seul exact).
class RidePreview {
  const RidePreview({
    required this.route,
    required this.estimated,
    required this.campus,
    required this.campusName,
    this.me,
    this.durationS,
  });

  factory RidePreview.fromJson(Map<String, dynamic> json) {
    (double, double) point(Object? p) {
      final map = p! as Map<String, dynamic>;
      return ((map['lat'] as num).toDouble(), (map['lon'] as num).toDouble());
    }

    return RidePreview(
      route: [
        for (final p in json['route'] as List<dynamic>)
          (((p as List<dynamic>)[0] as num).toDouble(), (p[1] as num).toDouble()),
      ],
      estimated: json['estimated'] as bool,
      campus: point(json['campus']),
      campusName: (json['campus'] as Map<String, dynamic>)['name'] as String,
      me: json['me'] == null ? null : point(json['me']),
      durationS: json['durationS'] as int?,
    );
  }

  final List<(double, double)> route;
  final bool estimated;
  final (double, double) campus;
  final String campusName;
  final (double, double)? me;

  /// Mon temps de trajet, en secondes (serveur).
  final int? durationS;
}
