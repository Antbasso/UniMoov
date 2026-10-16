import 'package:unimoov/features/trust/data/trust_api.dart';
import 'package:unimoov/features/trust/domain/trust.dart';
import 'package:unimoov/core/api/api_client.dart';
import 'package:unimoov/features/auth/data/auth_api.dart';
import 'package:unimoov/features/auth/domain/auth_tokens.dart';
import 'package:unimoov/features/profile/data/profile_api.dart';
import 'package:unimoov/features/profile/domain/me.dart';
import 'package:unimoov/features/proposals/data/proposals_api.dart';
import 'package:unimoov/features/proposals/domain/proposal.dart';
import 'package:unimoov/features/rides/data/rides_api.dart';
import 'package:unimoov/features/rides/domain/ride.dart';
import 'package:unimoov/features/schedule/data/schedule_api.dart';
import 'package:unimoov/features/wallet/data/wallet_api.dart';
import 'package:unimoov/features/wallet/domain/wallet.dart';
import 'package:unimoov/features/schedule/domain/schedule.dart';

/// Backend en mémoire qui reproduit les règles de l'API (docs/api.md) pour les tests de
/// parcours. Il survit à un « redémarrage » de l'app, comme le vrai serveur.
class FakeBackend
    implements AuthApi, ProfileApi, ScheduleApi, ProposalsApi, RidesApi, WalletApi, TrustApi {
  static const code = '123456';
  static const knownAddress = '12 rue de la Paix, Annecy';

  final Map<String, _Account> _accounts = {};
  final Map<String, String> _refreshToEmail = {};
  String? _currentEmail;
  int _tokenCounter = 0;
  final List<String> codesSentTo = [];

  /// Erreur à lever au prochain appel (une fois).
  ApiException? failNext;

  void _maybeFail() {
    final error = failNext;
    failNext = null;
    if (error != null) throw error;
  }

  AuthTokens _issue(String email) {
    _currentEmail = email;
    final refresh = 'refresh-${++_tokenCounter}';
    _refreshToEmail[refresh] = email;
    return AuthTokens(accessToken: 'access-$_tokenCounter', refreshToken: refresh);
  }

  _Account get _me {
    final account = _accounts[_currentEmail];
    if (account == null) throw const ApiException('unauthorized', '', statusCode: 401);
    return account;
  }

  // --- Auth ---

  @override
  Future<void> requestCode(String universityEmail) async {
    _maybeFail();
    if (!universityEmail.endsWith('univ-smb.fr')) {
      throw const ApiException('email_domain_not_allowed', '', statusCode: 400);
    }
    codesSentTo.add(universityEmail);
  }

  @override
  Future<AuthTokens> verify({
    required String universityEmail,
    required String code,
    required String firstName,
    required String lastName,
    required String password,
  }) async {
    _maybeFail();
    if (code != FakeBackend.code || !codesSentTo.contains(universityEmail)) {
      throw const ApiException('code_invalid', '', statusCode: 400);
    }
    if (_accounts.containsKey(universityEmail)) {
      throw const ApiException('account_exists', '', statusCode: 409);
    }
    _accounts[universityEmail] = _Account(universityEmail, firstName, lastName, password);
    return _issue(universityEmail);
  }

  @override
  Future<AuthTokens> login({required String universityEmail, required String password}) async {
    _maybeFail();
    final account = _accounts[universityEmail];
    if (account == null || account.password != password) {
      throw const ApiException('invalid_credentials', '', statusCode: 401);
    }
    return _issue(universityEmail);
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    final email = _refreshToEmail.remove(refreshToken);
    if (email == null) throw const ApiException('invalid_refresh_token', '', statusCode: 401);
    return _issue(email);
  }

  @override
  Future<void> logout(String refreshToken) async => _refreshToEmail.remove(refreshToken);

  /// Simule la reprise d'une session stockée (nouveau lancement de l'app).
  void resumeSessionFor(String email) => _currentEmail = email;

  // --- Profil ---

  @override
  Future<Me> getMe() async {
    _maybeFail();
    return _me.toMe();
  }

  @override
  Future<Me> updateNames({String? firstName, String? lastName}) async {
    _me
      ..firstName = firstName ?? _me.firstName
      ..lastName = lastName ?? _me.lastName;
    return _me.toMe();
  }

  @override
  Future<Me> setAddress(String address) async {
    _maybeFail();
    if (address != knownAddress) {
      throw const ApiException('address_not_found', '', statusCode: 422);
    }
    _me.home = const Home(address: '12 Rue de la Paix 74000 Annecy', lat: 45.9, lon: 6.12);
    return _me.toMe();
  }

  @override
  Future<Me> setVehicle(Vehicle vehicle) async {
    _me.vehicle = vehicle;
    return _me.toMe();
  }

  @override
  Future<void> removeVehicle() async {
    _me
      ..vehicle = null
      ..roleMode = RoleMode.alwaysPassenger;
  }

  @override
  Future<Me> setRoleMode(RoleMode mode) async {
    if (_me.vehicle == null && !mode.allowedWithoutVehicle()) {
      throw const ApiException('vehicle_required', '', statusCode: 409);
    }
    _me.roleMode = mode;
    return _me.toMe();
  }

  @override
  Future<Me> setDefaultNavApp(String app) async {
    _me.defaultNavApp = app;
    return _me.toMe();
  }

  @override
  Future<Me> setStep(OnboardingStep step, StepStatus status) async {
    _maybeFail();
    _me.steps[step] = status;
    return _me.toMe();
  }

  @override
  Future<List<Pause>> listPauses() async => List.of(_me.pauses);

  @override
  Future<Pause> addPause(DateTime startsOn, DateTime endsOn, int? everyWeeks) async {
    _maybeFail();
    final pause = Pause(
      id: 'pause-${_me.pauses.length + 1}',
      startsOn: startsOn,
      endsOn: endsOn,
      everyWeeks: everyWeeks,
    );
    _me.pauses.add(pause);
    return pause;
  }

  @override
  Future<void> removePause(String id) async => _me.pauses.removeWhere((p) => p.id == id);

  // --- Emploi du temps ---

  static const validIcs = 'https://ade.univ-smb.fr/cal.ics';
  CalendarConnection? connection;
  List<ManualDay> manualDays = [];

  @override
  Future<CalendarConnection?> getConnection() async => connection;

  @override
  Future<CalendarConnection> connectIcs(String url) async {
    _maybeFail();
    if (!url.startsWith('https://')) {
      throw const ApiException('calendar_url_invalid', '', statusCode: 400);
    }
    if (url != validIcs) throw const ApiException('calendar_unreachable', '', statusCode: 422);
    return connection = CalendarConnection(id: 'conn-1', consentedAt: DateTime(2026, 10, 18));
  }

  @override
  Future<CalendarConnection> sync() async => connection!;

  @override
  Future<void> disconnect(String id) async => connection = null;

  @override
  Future<List<ManualDay>> getManual() async => manualDays;

  @override
  Future<List<ManualDay>> setManual(List<ManualDay> days) async {
    _maybeFail();
    return manualDays = days;
  }

  // --- Propositions ---

  /// Propositions par semaine ISO ; alternatives et résultats de recherche préparés.
  final Map<String, List<Proposal>> weeks = {};
  final Map<String, List<JoinableRide>> alternativesById = {};
  List<JoinableRide> searchResults = [];
  final List<String> joined = [];

  @override
  Future<List<Proposal>> week(String week) async {
    _maybeFail();
    return List.of(weeks[week] ?? const []);
  }

  Proposal _replace(String id, Proposal Function(Proposal) change) {
    for (final entry in weeks.entries) {
      final index = entry.value.indexWhere((p) => p.id == id);
      if (index >= 0) return entry.value[index] = change(entry.value[index]);
    }
    throw const ApiException('not_found', '', statusCode: 404);
  }

  @override
  Future<Proposal> accept(String id) async {
    _maybeFail();
    final isJoin = weeks.values.every((list) => list.every((p) => p.id != id));
    if (isJoin) {
      joined.add(id);
      return proposalFixture(id: id, myStatus: 'accepted');
    }
    return _replace(id, (p) => p.copyWith(myStatus: 'accepted'));
  }

  @override
  Future<void> decline(String id) async {
    _maybeFail();
    for (final list in weeks.values) {
      list.removeWhere((p) => p.id == id);
    }
  }

  @override
  Future<List<JoinableRide>> alternatives(String id) async => alternativesById[id] ?? const [];

  @override
  Future<List<JoinableRide>> search({
    required DateTime day,
    required Direction direction,
    String? time,
  }) async {
    _maybeFail();
    return searchResults;
  }

  // --- Trajets confirmés ---

  /// Trajets par identifiant ; suggestions préparées par trajet.
  final Map<String, RideDetails> rides = {};
  final Map<String, Suggestions> suggestionsById = {};
  final List<String> invited = [];

  /// Erreur au prochain chargement d'un trajet seulement (rechargement après une action).
  ApiException? failNextRide;

  @override
  Future<RideDetails> ride(String id) async {
    _maybeFail();
    final rideError = failNextRide;
    failNextRide = null;
    if (rideError != null) throw rideError;
    final ride = rides[id];
    if (ride == null) throw const ApiException('forbidden', '', statusCode: 403);
    return ride;
  }

  @override
  Future<void> setMeetingPoint(String id, MeetingPoint? point) async {
    _maybeFail();
    final ride = rides[id]!;
    final myId = idOf(_me.email);
    rides[id] = ride.copyWithStops([
      for (final s in ride.stops)
        s.userId != myId
            ? s
            : RideStop(
                order: s.order,
                kind: s.kind,
                userId: s.userId,
                firstName: s.firstName,
                lastName: s.lastName,
                label: point?.label ?? knownAddress,
                lat: point?.lat ?? s.lat,
                lon: point?.lon ?? s.lon,
                eta: s.eta,
                isMeetingPoint: point != null,
              ),
    ]);
  }

  @override
  Future<Suggestions> suggestions(String id) async {
    _maybeFail();
    return suggestionsById[id] ?? const Suggestions(seatsLeft: 0, items: []);
  }

  @override
  Future<Proposal> invite(String id, String userId) async {
    _maybeFail();
    invited.add(userId);
    final current = suggestionsById[id]!;
    final person = current.items.firstWhere((s) => s.person.userId == userId).person;
    suggestionsById[id] = Suggestions(
      seatsLeft: current.seatsLeft - 1,
      currentPassengerPaysCents: current.currentPassengerPaysCents,
      items: current.items.where((s) => s.person.userId != userId).toList(),
    );
    return _replace(
      id,
      (p) => p.copyWith(
        passengers: [
          ...p.passengers,
          PublicPerson(
            userId: person.userId,
            firstName: person.firstName,
            reliabilityScore: person.reliabilityScore,
            detourMinutes: person.detourMinutes,
            status: 'proposed',
          ),
        ],
      ),
    );
  }

  // --- Cycle de vie et navigation ---

  final List<String> actions = [];

  RideDetails _withStatus(String id, String status, {List<RideStop>? stops}) {
    final ride = rides[id]!;
    return rides[id] = RideDetails(
      id: ride.id,
      day: ride.day,
      direction: ride.direction,
      time: ride.time,
      status: status,
      isDriver: ride.isDriver,
      myStatus: ride.myStatus,
      routeEstimated: ride.routeEstimated,
      route: ride.route,
      stops: stops ?? ride.stops,
      distanceM: ride.distanceM,
      durationS: ride.durationS,
      price: ride.price,
    );
  }

  RideStop _stopWith(RideStop s, {bool? pickedUp, bool? presenceValidated}) => RideStop(
    order: s.order,
    kind: s.kind,
    userId: s.userId,
    firstName: s.firstName,
    lastName: s.lastName,
    label: s.label,
    lat: s.lat,
    lon: s.lon,
    eta: s.eta,
    isMeetingPoint: s.isMeetingPoint,
    pickedUp: pickedUp ?? s.pickedUp,
    presenceValidated: presenceValidated ?? s.presenceValidated,
  );

  @override
  Future<void> start(String id) async {
    _maybeFail();
    actions.add('start:$id');
    _withStatus(id, 'in_progress');
  }

  @override
  Future<void> pickedUp(String id, String userId) async {
    _maybeFail();
    actions.add('picked_up:$userId');
    final ride = rides[id]!;
    _withStatus(
      id,
      ride.status,
      stops: [for (final s in ride.stops) s.userId == userId ? _stopWith(s, pickedUp: true) : s],
    );
  }

  @override
  Future<NavigationPlan> navigation(String id) async {
    _maybeFail();
    final ride = rides[id]!;
    final passengers = ride.stops.where((s) => s.kind == StopKind.passenger).toList();
    final stops = [...passengers, ride.stops.last];
    final remaining = stops.where((s) => !s.pickedUp).toList();
    String coord(RideStop s) => '${s.lat.toStringAsFixed(6)},${s.lon.toStringAsFixed(6)}';
    final last = remaining.isEmpty ? stops.last : remaining.last;
    final waypoints = remaining.isEmpty ? <RideStop>[] : remaining.sublist(0, remaining.length - 1);
    return NavigationPlan(
      stops: [
        for (final (i, s) in stops.indexed)
          NavigationStop(
            order: i + 1,
            isDestination: s.kind != StopKind.passenger,
            userId: s.userId,
            firstName: s.firstName,
            label: s.label,
            eta: s.eta,
            pickedUp: s.pickedUp,
          ),
      ],
      googleMaps:
          'https://www.google.com/maps/dir/?api=1&destination=${coord(last)}'
          '${waypoints.isEmpty ? '' : '&waypoints=${waypoints.map(coord).join('%7C')}'}&travelmode=driving',
      appleMaps: 'https://maps.apple.com/?daddr=${remaining.map(coord).join('+to:')}&dirflg=d',
      wazeNextStop:
          'https://waze.com/ul?ll=${coord(remaining.isEmpty ? last : remaining.first)}&navigate=yes',
    );
  }

  @override
  Future<bool> presence(String id) async {
    _maybeFail();
    final ride = rides[id]!;
    final me = idOf(_me.email);
    _withStatus(
      id,
      ride.status,
      stops: [
        for (final s in ride.stops) s.userId == me ? _stopWith(s, presenceValidated: true) : s,
      ],
    );
    actions.add('presence');
    return true;
  }

  @override
  Future<void> finish(String id) async {
    _maybeFail();
    actions.add('finish');
    _withStatus(id, 'completed');
  }

  // --- Portefeuille ---

  int balanceCents = 0;
  final List<WalletEntry> walletHistory = [];
  final Set<String> topupKeys = {};

  Wallet get _wallet =>
      Wallet(balanceCents: balanceCents, heldCents: 0, history: List.of(walletHistory));

  @override
  Future<Wallet> wallet() async {
    _maybeFail();
    return _wallet;
  }

  @override
  Future<Wallet> topup(int amountCents, String idempotencyKey) async {
    _maybeFail();
    // Même clé : aucune nouvelle écriture (comme le serveur).
    if (topupKeys.add(idempotencyKey)) {
      balanceCents += amountCents;
      walletHistory.insert(
        0,
        WalletEntry(kind: 'topup', amountCents: amountCents, at: DateTime(2026, 10, 15, 9)),
      );
    }
    return _wallet;
  }

  // --- Confiance (annulations, notes, fiabilité, litiges, signalements) ---

  CancelTier cancelTier = CancelTier.medium;
  final List<String> cancelled = [];
  final Map<String, RideRatings> ratingsById = {};
  final Map<String, int> _given = {};
  Reliability reliabilityState = reliabilityFixture();
  final Map<String, List<Dispute>> disputesById = {};
  final List<({String userId, ReportReason reason, String? message})> reports = [];
  int _disputeCounter = 0;

  @override
  Future<CancellationInfo> cancellation(String rideId) async {
    _maybeFail();
    final ride = rides[rideId];
    final proposal = weeks.values.expand((w) => w).where((p) => p.id == rideId).firstOrNull;
    if (ride == null && proposal == null) {
      throw const ApiException('not_found', '', statusCode: 404);
    }
    return CancellationInfo(isDriver: ride?.isDriver ?? proposal!.isDriver, tier: cancelTier);
  }

  @override
  Future<CancelTier> cancel(String rideId) async {
    _maybeFail();
    cancelled.add(rideId);
    rides.remove(rideId);
    for (final list in weeks.values) {
      final i = list.indexWhere((p) => p.id == rideId);
      if (i >= 0) list[i] = list[i].copyWith(myStatus: 'cancelled');
    }
    return cancelTier;
  }

  @override
  Future<RideRatings> ratings(String rideId) async {
    _maybeFail();
    final base = ratingsById[rideId] ?? const RideRatings(open: true, people: []);
    return RideRatings(
      open: base.open,
      people: [
        for (final p in base.people)
          if (_given['$rideId|${p.userId}'] case final stars?) p.withStars(stars) else p,
      ],
    );
  }

  @override
  Future<void> rate(String rideId, String userId, int stars) async {
    _maybeFail();
    final key = '$rideId|$userId';
    if (_given.containsKey(key)) throw const ApiException('already_rated', '', statusCode: 409);
    _given[key] = stars;
  }

  /// Notes données (trajet|personne → étoiles).
  Map<String, int> get given => Map.unmodifiable(_given);

  @override
  Future<Reliability> reliability() async {
    _maybeFail();
    return reliabilityState;
  }

  @override
  Future<List<Dispute>> disputes(String rideId) async {
    _maybeFail();
    return List.of(disputesById[rideId] ?? const []);
  }

  @override
  Future<Dispute> openDispute(String rideId, DisputeReason reason, String? message) async {
    _maybeFail();
    final list = disputesById.putIfAbsent(rideId, () => []);
    if (list.any((d) => d.reason == reason)) {
      throw const ApiException('dispute_exists', '', statusCode: 409);
    }
    // Mêmes règles que l'arbitrage du serveur pour les cas sans preuve contraire.
    final dispute = switch (reason) {
      DisputeReason.cancellationPenalty => Dispute(
        id: 'dispute-${++_disputeCounter}',
        reason: reason,
        level: 1,
        decision: DisputeDecision.upheld,
        explanation: 'penalty_matches_timestamps',
      ),
      DisputeReason.markedAbsent => Dispute(
        id: 'dispute-${++_disputeCounter}',
        reason: reason,
        level: 1,
        decision: DisputeDecision.upheld,
        explanation: 'no_presence_evidence',
      ),
      _ => Dispute(
        id: 'dispute-${++_disputeCounter}',
        reason: reason,
        level: 2,
        decision: DisputeDecision.escalated,
        explanation: 'needs_human',
      ),
    };
    list.add(dispute);
    return dispute;
  }

  @override
  Future<Dispute> escalate(String disputeId, String? message) async {
    _maybeFail();
    for (final list in disputesById.values) {
      final i = list.indexWhere((d) => d.id == disputeId);
      if (i >= 0) {
        final d = list[i];
        return list[i] = Dispute(
          id: d.id,
          reason: d.reason,
          level: 2,
          decision: DisputeDecision.escalated,
          explanation: d.explanation,
        );
      }
    }
    throw const ApiException('not_found', '', statusCode: 404);
  }

  @override
  Future<void> report(String userId, ReportReason reason, String? message) async {
    _maybeFail();
    reports.add((userId: userId, reason: reason, message: message));
  }

  /// Identifiant serveur d'un compte (pour les arrêts « Toi »).
  String idOf(String email) => 'id-$email';

  /// Accès direct pour préparer un état (tests).
  void seedAccount(
    String email, {
    String firstName = 'Léa',
    Map<OnboardingStep, StepStatus>? steps,
    bool withHome = false,
  }) {
    _accounts[email] = _Account(email, firstName, 'Martin', 'motdepasse-solide')
      ..steps.addAll(steps ?? {})
      ..home = withHome
          ? const Home(address: '12 Rue de la Paix 74000 Annecy', lat: 45.9, lon: 6.12)
          : null;
  }
}

class _Account {
  _Account(this.email, this.firstName, this.lastName, this.password);

  final String email;
  String firstName;
  String lastName;
  final String password;
  Home? home;
  Vehicle? vehicle;
  RoleMode roleMode = RoleMode.alwaysPassenger;
  String? defaultNavApp;
  final Map<OnboardingStep, StepStatus> steps = {};
  final List<Pause> pauses = [];

  Me toMe() {
    final next = OnboardingStep.values.where((s) => !steps.containsKey(s)).firstOrNull;
    final today = DateTime.now();
    return Me(
      id: 'id-$email',
      universityEmail: email,
      firstName: firstName,
      lastName: lastName,
      home: home,
      roleMode: roleMode,
      vehicle: vehicle,
      steps: Map.of(steps),
      nextStep: next,
      onboardingCompleted: next == null,
      discoveryMode: home == null,
      pausedToday: pauses.any((p) => !today.isBefore(p.startsOn) && !today.isAfter(p.endsOn)),
      defaultNavApp: defaultNavApp,
    );
  }
}

const _driver = PublicPerson(
  userId: 'driver-1',
  firstName: 'Nathan',
  reliabilityScore: 0.9,
  detourMinutes: 4,
  status: 'proposed',
);

/// Proposition de test (passager par défaut), au format renvoyé par l'API.
Proposal proposalFixture({
  String id = 'ride-1',
  DateTime? day,
  Direction direction = Direction.toCampus,
  bool isDriver = false,
  String myStatus = 'proposed',
  String rideStatus = 'proposed',
  List<PublicPerson> passengers = const [],
}) {
  final date = day ?? DateTime(2026, 10, 19);
  return Proposal(
    id: id,
    day: date,
    direction: direction,
    time: DateTime(date.year, date.month, date.day, 8),
    isDriver: isDriver,
    myStatus: myStatus,
    rideStatus: rideStatus,
    seatsTotal: 3,
    seatsTaken: isDriver ? passengers.length : 1,
    detourMinutes: 4,
    driver: isDriver ? null : _driver,
    passengers: passengers,
  );
}

extension ProposalCopy on Proposal {
  Proposal copyWith({String? myStatus, String? rideStatus, List<PublicPerson>? passengers}) =>
      Proposal(
        id: id,
        day: day,
        direction: direction,
        time: time,
        isDriver: isDriver,
        myStatus: myStatus ?? this.myStatus,
        rideStatus: rideStatus ?? this.rideStatus,
        seatsTotal: seatsTotal,
        seatsTaken: seatsTaken,
        detourMinutes: detourMinutes,
        driver: driver,
        passengers: passengers ?? this.passengers,
      );
}

extension RideCopy on RideDetails {
  RideDetails copyWithStops(List<RideStop> stops) => RideDetails(
    id: id,
    day: day,
    direction: direction,
    time: time,
    status: status,
    isDriver: isDriver,
    myStatus: myStatus,
    routeEstimated: routeEstimated,
    route: [for (final s in stops) (s.lat, s.lon)],
    stops: stops,
    distanceM: distanceM,
    durationS: durationS,
    price: price,
  );
}

/// Trajet confirmé de test : Nathan conduit, Léa (l'utilisatrice) et Hugo montent.
RideDetails rideFixture({
  String id = 'ride-1',
  bool isDriver = false,
  String me = 'id-lea@etu.univ-smb.fr',
  String status = 'confirmed',
  String myStatus = 'accepted',
}) {
  final day = DateTime(2026, 10, 19);
  final stops = [
    RideStop(
      order: 0,
      kind: StopKind.driver,
      userId: isDriver ? me : 'driver-1',
      firstName: isDriver ? 'Léa' : 'Nathan',
      lastName: isDriver ? 'Martin' : 'Petit',
      label: 'Centre, 74320 Sévrier',
      lat: 45.864,
      lon: 6.141,
      eta: DateTime.utc(2026, 10, 19, 5, 41),
      isMeetingPoint: false,
    ),
    RideStop(
      order: 1,
      kind: StopKind.passenger,
      userId: isDriver ? 'passenger-2' : me,
      firstName: isDriver ? 'Inès' : 'Léa',
      lastName: isDriver ? 'Robert' : 'Martin',
      label: '12 Rue de la Paix 74000 Annecy',
      lat: 45.9,
      lon: 6.12,
      eta: DateTime.utc(2026, 10, 19, 5, 49),
      isMeetingPoint: false,
    ),
    RideStop(
      order: 2,
      kind: StopKind.passenger,
      userId: 'passenger-3',
      firstName: 'Hugo',
      // Vu par un autre passager : secteur seulement (le serveur retire l'adresse).
      label: isDriver ? 'Centre, 74960 Cran-Gevrier' : '',
      lat: 45.905,
      lon: 6.103,
      eta: DateTime.utc(2026, 10, 19, 5, 53),
      isMeetingPoint: false,
    ),
    RideStop(
      order: 3,
      kind: StopKind.campus,
      label: "Campus d'Annecy (USMB)",
      lat: 45.9195,
      lon: 6.158,
      eta: DateTime.utc(2026, 10, 19, 6),
      isMeetingPoint: false,
    ),
  ];
  return RideDetails(
    id: id,
    day: day,
    direction: Direction.toCampus,
    time: DateTime.utc(2026, 10, 19, 6),
    status: status,
    isDriver: isDriver,
    myStatus: myStatus,
    routeEstimated: false,
    route: [for (final s in stops) (s.lat, s.lon)],
    stops: stops,
    distanceM: 14200,
    durationS: 1140,
    price: RidePrice(
      totalCostCents: 166,
      persons: 3,
      shareCents: 56,
      commissionCents: 20,
      youPayCents: isDriver ? null : 76,
      youReceiveCents: isDriver ? 112 : null,
    ),
  );
}

const _theo = PublicPerson(
  userId: 'theo',
  firstName: 'Théo',
  reliabilityScore: 0.8,
  detourMinutes: 14,
  status: 'suggested',
);

/// Prépare Léa : passagère confirmée le lundi, conductrice confirmée le mardi.
FakeBackend rideBackend() {
  final backend = FakeBackend()
    ..seedAccount(
      'lea@etu.univ-smb.fr',
      steps: {for (final s in OnboardingStep.values) s: StepStatus.done},
      withHome: true,
    )
    ..resumeSessionFor('lea@etu.univ-smb.fr');
  const ines = PublicPerson(
    userId: 'passenger-2',
    firstName: 'Inès',
    reliabilityScore: 0.9,
    detourMinutes: 3,
    status: 'accepted',
  );
  // Semaine de la date de référence des tests (jeudi 15 octobre 2026).
  backend.weeks['2026-W42'] = [
    proposalFixture(
      id: 'ride-1',
      day: DateTime(2026, 10, 12),
      myStatus: 'accepted',
      rideStatus: 'confirmed',
    ),
    proposalFixture(
      id: 'ride-2',
      day: DateTime(2026, 10, 13),
      isDriver: true,
      myStatus: 'accepted',
      rideStatus: 'confirmed',
      passengers: const [ines],
    ),
  ];
  backend.rides['ride-1'] = rideFixture();
  backend.rides['ride-2'] = rideFixture(id: 'ride-2', isDriver: true);
  backend.suggestionsById['ride-2'] = const Suggestions(
    seatsLeft: 2,
    currentPassengerPaysCents: 76,
    items: [
      Suggestion(person: _theo, withinDetourLimit: false, shareCents: 48, passengerPaysCents: 68),
    ],
  );
  return backend;
}

/// Score de Léa : un trajet annulé tard, contestable, et une absence plus ancienne.
Reliability reliabilityFixture({List<ReliabilityEvent>? events}) => Reliability(
  score: 0.74,
  windowDays: 180,
  completedRides: 12,
  cancellations: 1,
  noShows: 1,
  ratingsCount: 9,
  averageStars: 4.6,
  events:
      events ??
      [
        ReliabilityEvent(
          kind: ReliabilityEventKind.cancelLate,
          rideId: 'ride-9',
          day: DateTime(2026, 10, 13),
          createdAt: DateTime.utc(2026, 10, 13, 5, 30),
          disputeReason: DisputeReason.cancellationPenalty,
        ),
        ReliabilityEvent(
          kind: ReliabilityEventKind.noShow,
          rideId: 'ride-8',
          day: DateTime(2026, 9, 2),
          createdAt: DateTime.utc(2026, 9, 2, 7),
        ),
      ],
);
