import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../../../core/api/api_client.dart';
import '../../account/data/account_api.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/domain/auth_tokens.dart';
import '../../chat/data/chat_api.dart';
import '../../chat/data/user_socket.dart';
import '../../chat/domain/chat.dart';
import '../../notifications/data/notifications_api.dart';
import '../../profile/data/profile_api.dart';
import '../../profile/domain/me.dart';
import '../../proposals/data/proposals_api.dart';
import '../../proposals/domain/proposal.dart';
import '../../rides/data/live_channel.dart';
import '../../rides/data/rides_api.dart';
import '../../rides/domain/ride.dart';
import '../../schedule/data/schedule_api.dart';
import '../../schedule/domain/schedule.dart';
import '../../trust/data/trust_api.dart';
import '../../trust/domain/trust.dart';
import '../../wallet/data/wallet_api.dart';
import '../../wallet/domain/wallet.dart';
import 'demo_routes.g.dart';
import 'demo_world.dart';

/// Serveur fictif du mode démo, entièrement dans l'app : mêmes règles que l'API (docs/api.md)
/// sur des données inventées, sans réseau. Le suivi en direct est simulé (le conducteur avance
/// tout seul, la présence se valide à la prise en charge).
typedef _Point = ({String? userId, String label, double lat, double lon, bool meeting});

class DemoBackend
    implements
        AuthApi,
        ProfileApi,
        ScheduleApi,
        ProposalsApi,
        RidesApi,
        WalletApi,
        TrustApi,
        ChatApi,
        NotificationsApi,
        AccountApi {
  /// `withAccount` : compte de Camille prêt à l'emploi ; sinon parcours d'inscription complet.
  DemoBackend({
    required this._clock,
    bool withAccount = true,
    this.latency = const Duration(milliseconds: 250),
    this.tick = const Duration(seconds: 2),
  }) {
    if (withAccount) {
      _account = _DemoAccount(demoEmail, 'Camille', 'Durand', demoPassword)
        ..home = const Home(address: 'Centre, 74600 Seynod', lat: 45.8865, lon: 6.089)
        ..vehicle = const Vehicle(consumptionLPer100km: 5.5, defaultSeats: 3, maxDetourMinutes: 10)
        ..roleMode = RoleMode.auto
        ..steps.addAll({for (final s in OnboardingStep.values) s: StepStatus.done});
      _seedScenario();
    }
  }

  final DateTime Function() _clock;

  /// Suivi en direct et socket de messagerie simulés.
  late final LiveConnector live = _DemoLiveConnector(this);
  late final UserSocketConnector chatSocket = _DemoSocketConnector(this);

  /// Délai simulé de chaque appel (affiche les états de chargement).
  final Duration latency;

  /// Rythme du suivi simulé.
  final Duration tick;

  _DemoAccount? _account;
  bool _signedIn = false;
  final Set<String> _codesSent = {};
  int _counter = 0;

  DateTime get _now => _clock();
  DateTime get _today => DateTime(_now.year, _now.month, _now.day);
  String _id(String prefix) => '$prefix-${++_counter}';

  Future<void> _wait() => latency == Duration.zero ? Future.value() : Future.delayed(latency);

  _DemoAccount get _me {
    final account = _account;
    if (account == null || !_signedIn) {
      throw const ApiException('unauthorized', '', statusCode: 401);
    }
    return account;
  }

  // --- Scénario ---

  final Map<String, DemoRide> _rides = {};
  final Set<String> _hidden = {};
  int balanceCents = 0;
  int heldCents = 0;
  final List<WalletEntry> _history = [];
  final Map<String, int> _held = {};

  void _entry(String kind, int amountCents, DateTime at) =>
      _history.insert(0, WalletEntry(kind: kind, amountCents: amountCents, at: at));

  DateTime _at(DateTime day, int hour, [int minute = 0]) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  /// Heure ronde au quart d'heure suivant, au moins `minutes` plus tard.
  DateTime _soon(int minutes) {
    final t = _now.add(Duration(minutes: minutes));
    return DateTime(t.year, t.month, t.day, t.hour, (t.minute ~/ 15 + 1) * 15);
  }

  /// Semaine de Camille : un trajet en cours (passagère), un trajet à conduire bientôt, des
  /// propositions à accepter, une demande de place, des trajets terminés à noter.
  void _seedScenario() {
    final today = _today;
    final tomorrow = today.add(const Duration(days: 1));
    final later = today.add(const Duration(days: 2));
    final past = today.weekday > DateTime.monday ? today.subtract(const Duration(days: 1)) : today;
    final lastWeek = today.subtract(const Duration(days: 7));

    // En cours : Nathan conduit Camille au campus ; il approche de chez elle.
    _add(
      DemoRide(
        id: 'demo-live',
        day: today,
        direction: Direction.toCampus,
        time: _now.add(const Duration(minutes: 12)),
        driverId: 'nathan',
        driverStatus: 'accepted',
        status: 'in_progress',
        consumption: 6.5,
        seats: [DemoSeat(demoMeId, 'accepted', detourMinutes: 4)],
      ),
    );
    // Retour à conduire : Camille ramène Inès et Hugo ; démarrable tout de suite.
    _add(
      DemoRide(
        id: 'demo-drive',
        day: today,
        direction: Direction.fromCampus,
        time: _soon(20),
        driverId: demoMeId,
        driverStatus: 'accepted',
        status: 'confirmed',
        consumption: 5.5,
        seats: [
          DemoSeat('ines', 'accepted', detourMinutes: 3),
          DemoSeat('hugo', 'accepted', detourMinutes: 2),
        ],
      ),
    );
    // Demain : Léa propose de prendre Camille (Léa a déjà accepté).
    _add(
      DemoRide(
        id: 'demo-offer',
        day: tomorrow,
        direction: Direction.toCampus,
        time: _at(tomorrow, 8),
        driverId: 'lea',
        driverStatus: 'accepted',
        seats: [DemoSeat(demoMeId, 'proposed', detourMinutes: 3)],
      ),
    );
    // Demain soir : Camille conduit ; Hugo proposé, Manon demande une place.
    _add(
      DemoRide(
        id: 'demo-requests',
        day: tomorrow,
        direction: Direction.fromCampus,
        time: _at(tomorrow, 17, 30),
        driverId: demoMeId,
        driverStatus: 'proposed',
        consumption: 5.5,
        seats: [
          DemoSeat('hugo', 'proposed', detourMinutes: 2)
            ..autoAcceptAt = _now.add(const Duration(seconds: 20)),
          DemoSeat('manon', 'requested', detourMinutes: 6),
        ],
      ),
    );
    // Après-demain : Lucas vient de Rumilly, trajet long : prix maximal au-dessus du solde.
    _add(
      DemoRide(
        id: 'demo-expensive',
        day: later,
        direction: Direction.toCampus,
        time: _at(later, 8, 30),
        driverId: 'lucas',
        driverStatus: 'accepted',
        consumption: 9.5,
        seatsTotal: 2,
        seats: [DemoSeat(demoMeId, 'proposed', detourMinutes: 9)],
      ),
    );
    // Terminés : à noter, avec litige ou signalement possibles.
    _add(
      DemoRide(
        id: 'demo-done-passenger',
        day: past,
        direction: Direction.toCampus,
        time: _at(past, 7, 45),
        driverId: 'nathan',
        driverStatus: 'accepted',
        status: 'completed',
        consumption: 6.5,
        seats: [
          DemoSeat(demoMeId, 'accepted')
            ..presenceValidated = true
            ..pickedUp = true
            ..arrived = true
            ..ended = true,
        ],
      ),
    );
    _add(
      DemoRide(
        id: 'demo-done-driver',
        day: past,
        direction: Direction.fromCampus,
        time: _at(past, 17),
        driverId: demoMeId,
        driverStatus: 'accepted',
        status: 'completed',
        consumption: 5.5,
        seats: [
          for (final id in ['ines', 'hugo'])
            DemoSeat(id, 'accepted')
              ..presenceValidated = true
              ..pickedUp = true
              ..arrived = true
              ..ended = true,
        ],
      ),
    );

    // Portefeuille : recharges et trajets passés ; la retenue du trajet en cours.
    // Assez pour le trajet de Léa, pas pour le long trajet de Lucas (fenêtre « Solde insuffisant »).
    balanceCents = 300;
    _entry('topup', 1000, _at(lastWeek, 9, 12));
    _entry('ride_charge', -_priceOf(_rides['demo-done-passenger']!).youPay, _at(past, 8, 10));
    _entry('ride_credit', _priceOf(_rides['demo-done-driver']!).youReceive, _at(past, 17, 40));
    final live = _rides['demo-live']!;
    _hold(live);

    _manual = const [
      ManualDay(weekday: 1, startTime: '08:00', endTime: '17:00'),
      ManualDay(weekday: 2, startTime: '08:00', endTime: '17:30'),
      ManualDay(weekday: 3, startTime: '09:00', endTime: '12:00'),
      ManualDay(weekday: 4, startTime: '08:00', endTime: '17:00'),
      ManualDay(weekday: 5, startTime: '08:30', endTime: '16:00'),
    ];
    _seedChats();
    _events.addAll([
      ReliabilityEvent(
        kind: ReliabilityEventKind.cancelMedium,
        rideId: 'demo-old',
        day: lastWeek,
        createdAt: _at(lastWeek, 6, 50),
        disputeReason: DisputeReason.cancellationPenalty,
      ),
    ]);
  }

  void _add(DemoRide ride) => _rides[ride.id] = ride;

  // --- Calculs : arrêts, heures de passage, prix ---

  ({String label, double lat, double lon}) _pointOf(String personId) {
    if (personId == demoMeId) {
      final home = _account?.home;
      return (
        label: home?.address ?? 'Annecy',
        lat: home?.lat ?? 45.8992,
        lon: home?.lon ?? 6.1294,
      );
    }
    final p = demoPeople[personId]!;
    return (label: p.label, lat: p.lat, lon: p.lon);
  }

  String _firstName(String personId) =>
      personId == demoMeId ? (_account?.firstName ?? 'Toi') : demoPeople[personId]!.firstName;

  String _lastName(String personId) =>
      personId == demoMeId ? (_account?.lastName ?? '') : demoPeople[personId]!.lastName;

  double _score(String personId) => personId == demoMeId ? 0.92 : demoPeople[personId]!.score;

  /// Points du trajet dans l'ordre : domicile du conducteur, passagers, campus (aller).
  List<_Point> _path(DemoRide r, {bool all = false}) {
    final driver = _pointOf(r.driverId);
    final seats = r.seats.where((s) => all ? s.status != 'declined' : s.active).toList()
      ..sort((a, b) {
        final pa = _pointOf(a.personId);
        final pb = _pointOf(b.personId);
        return demoDistance(
          driver.lat,
          driver.lon,
          pa.lat,
          pa.lon,
        ).compareTo(demoDistance(driver.lat, driver.lon, pb.lat, pb.lon));
      });
    final passengers = <_Point>[
      for (final s in seats)
        if (s.meetingPoint case final m?)
          (userId: s.personId, label: m.label, lat: m.lat, lon: m.lon, meeting: true)
        else
          () {
            final p = _pointOf(s.personId);
            return (userId: s.personId, label: p.label, lat: p.lat, lon: p.lon, meeting: false);
          }(),
    ];
    final _Point start = (
      userId: r.driverId,
      label: driver.label,
      lat: driver.lat,
      lon: driver.lon,
      meeting: false,
    );
    const _Point campus = (
      userId: null,
      label: "Campus d'Annecy (USMB)",
      lat: 45.9195,
      lon: 6.158,
      meeting: false,
    );
    return r.direction == Direction.toCampus
        ? [start, ...passengers, campus]
        : [campus, ...passengers.reversed, start];
  }

  /// Lieu précalculé correspondant à un arrêt (à 50 m près) ; aucun pour un point de rendez-vous.
  String? _placeOf(_Point p) {
    if (p.meeting) return null;
    for (final MapEntry(:key, value: (lat, lon)) in demoPlaces.entries) {
      if (demoDistance(p.lat, p.lon, lat, lon) < 50) return key;
    }
    return null;
  }

  /// Tronçon routier réel entre deux arrêts (tracé OSRM précalculé), sinon ligne droite.
  List<(double, double)> _leg(_Point a, _Point b) {
    final from = _placeOf(a);
    final to = _placeOf(b);
    final route = from == null || to == null ? null : demoRoutes['$from|$to'];
    if (route == null) return [(a.lat, a.lon), (b.lat, b.lon)];
    return decodePolyline(route.$1);
  }

  /// Tracé routier complet d'un trajet, arrêt par arrêt.
  List<(double, double)> _road(List<_Point> path) => [
    for (var i = 1; i < path.length; i++)
      ...(i == 1 ? _leg(path[0], path[1]) : _leg(path[i - 1], path[i]).skip(1)),
  ];

  static double _lineLength(List<(double, double)> line) {
    var total = 0.0;
    for (var i = 1; i < line.length; i++) {
      total += demoDistance(line[i - 1].$1, line[i - 1].$2, line[i].$1, line[i].$2);
    }
    return total;
  }

  double _length(List<_Point> path) {
    var total = 0.0;
    for (var i = 1; i < path.length; i++) {
      total += demoDistance(path[i - 1].lat, path[i - 1].lon, path[i].lat, path[i].lon);
    }
    return total;
  }

  ({int cost, int persons, int share, int youPay, int youReceive}) _priceOf(
    DemoRide r, {
    int? persons,
  }) {
    final cost = demoCostCents(_length(_path(r)), r.consumption);
    final count = persons ?? r.activeSeats.length + 1;
    final share = (cost / count).ceil();
    final passengers = max(count - 1, 0);
    return (
      cost: cost,
      persons: count,
      share: share,
      youPay: share + demoCommissionCents,
      youReceive: share * passengers,
    );
  }

  /// Prix maximal pour Camille passagère : celui d'un trajet à deux (cahier §5).
  int _maxPrice(DemoRide r) {
    final driver = _pointOf(r.driverId);
    final me = _pointOf(demoMeId);
    final meters =
        demoDistance(driver.lat, driver.lon, me.lat, me.lon) +
        demoDistance(me.lat, me.lon, demoCampus.lat, demoCampus.lon);
    return (demoCostCents(meters, r.consumption) / 2).ceil() + demoCommissionCents;
  }

  void _hold(DemoRide r) {
    if (r.driverIsMe || _held.containsKey(r.id)) return;
    final max = _maxPrice(r);
    _held[r.id] = max;
    balanceCents -= max;
    heldCents += max;
  }

  // --- Auth ---

  @override
  Future<void> requestCode(String universityEmail) async {
    await _wait();
    if (!universityEmail.trim().toLowerCase().endsWith('univ-smb.fr')) {
      throw const ApiException('email_domain_not_allowed', '', statusCode: 400);
    }
    _codesSent.add(universityEmail.trim().toLowerCase());
  }

  @override
  Future<AuthTokens> verify({
    required String universityEmail,
    required String code,
    required String firstName,
    required String lastName,
    required String password,
  }) async {
    await _wait();
    final email = universityEmail.trim().toLowerCase();
    if (code != demoCode || !_codesSent.contains(email)) {
      throw const ApiException('code_invalid', '', statusCode: 400);
    }
    _account = _DemoAccount(email, firstName, lastName, password);
    return _issue();
  }

  @override
  Future<AuthTokens> login({required String universityEmail, required String password}) async {
    await _wait();
    final account = _account;
    if (account == null ||
        account.email != universityEmail.trim().toLowerCase() ||
        account.password != password) {
      throw const ApiException('invalid_credentials', '', statusCode: 401);
    }
    return _issue();
  }

  /// Connexion directe au compte de démonstration (bouton « Essayer la démo »).
  AuthTokens signInDemo() => _issue();

  AuthTokens _issue() {
    _signedIn = true;
    return AuthTokens(accessToken: _id('demo-access'), refreshToken: _id('demo-refresh'));
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async => _issue();

  @override
  Future<void> logout(String refreshToken) async {
    _signedIn = false;
    _closeAllLive();
  }

  // --- Profil ---

  @override
  Future<Me> getMe() async {
    await _wait();
    return _me.toMe(_today);
  }

  @override
  Future<Me> updateNames({String? firstName, String? lastName}) async {
    await _wait();
    _me
      ..firstName = firstName ?? _me.firstName
      ..lastName = lastName ?? _me.lastName;
    return _me.toMe(_today);
  }

  @override
  Future<Me> setAddress(String address) async {
    await _wait();
    if (address.trim().length < 3) {
      throw const ApiException('address_not_found', '', statusCode: 422);
    }
    // Géocodage fictif : centre d'Annecy, à 3 km du campus.
    _me.home = Home(address: address.trim(), lat: 45.8992, lon: 6.1294);
    return _me.toMe(_today);
  }

  @override
  Future<Me> setVehicle(Vehicle vehicle) async {
    await _wait();
    _me.vehicle = vehicle;
    return _me.toMe(_today);
  }

  @override
  Future<void> removeVehicle() async {
    await _wait();
    _me
      ..vehicle = null
      ..roleMode = RoleMode.alwaysPassenger;
  }

  @override
  Future<Me> setRoleMode(RoleMode mode) async {
    await _wait();
    if (_me.vehicle == null && !mode.allowedWithoutVehicle()) {
      throw const ApiException('vehicle_required', '', statusCode: 409);
    }
    _me.roleMode = mode;
    return _me.toMe(_today);
  }

  @override
  Future<Me> setDefaultNavApp(String app) async {
    await _wait();
    _me.defaultNavApp = app;
    return _me.toMe(_today);
  }

  @override
  Future<Me> setStep(OnboardingStep step, StepStatus status) async {
    await _wait();
    _me.steps[step] = status;
    // Inscription terminée : la semaine de démonstration apparaît.
    if (_me.toMe(_today).onboardingCompleted && _rides.isEmpty) _seedScenario();
    return _me.toMe(_today);
  }

  @override
  Future<List<Pause>> listPauses() async {
    await _wait();
    return List.of(_me.pauses);
  }

  @override
  Future<Pause> addPause(DateTime startsOn, DateTime endsOn, int? everyWeeks) async {
    await _wait();
    if (endsOn.isBefore(startsOn)) throw const ApiException('invalid_pause', '', statusCode: 400);
    final pause = Pause(
      id: _id('pause'),
      startsOn: startsOn,
      endsOn: endsOn,
      everyWeeks: everyWeeks,
    );
    _me.pauses.add(pause);
    return pause;
  }

  @override
  Future<void> removePause(String id) async {
    await _wait();
    _me.pauses.removeWhere((p) => p.id == id);
  }

  // --- Emploi du temps ---

  CalendarConnection? _connection;
  List<ManualDay> _manual = [];

  @override
  Future<CalendarConnection?> getConnection() async {
    await _wait();
    return _connection;
  }

  @override
  Future<CalendarConnection> connectIcs(String url) async {
    await _wait();
    if (!url.startsWith('https://')) {
      throw const ApiException('calendar_url_invalid', '', statusCode: 400);
    }
    return _connection = CalendarConnection(id: _id('cal'), consentedAt: _now, lastSyncedAt: _now);
  }

  @override
  Future<CalendarConnection> sync() async {
    await _wait();
    final c = _connection!;
    return _connection = CalendarConnection(
      id: c.id,
      consentedAt: c.consentedAt,
      lastSyncedAt: _now,
    );
  }

  @override
  Future<void> disconnect(String id) async {
    await _wait();
    _connection = null;
  }

  @override
  Future<List<ManualDay>> getManual() async {
    await _wait();
    return _manual;
  }

  @override
  Future<List<ManualDay>> setManual(List<ManualDay> days) async {
    await _wait();
    return _manual = days;
  }

  // --- Propositions ---

  /// Réponses automatiques arrivées (l'autre personne a accepté entre-temps).
  void _settle() {
    for (final r in _rides.values) {
      for (final s in r.seats) {
        final at = s.autoAcceptAt;
        if (at != null && !_now.isBefore(at) && s.status != 'accepted') {
          s
            ..status = 'accepted'
            ..autoAcceptAt = null;
        }
      }
      if (r.status == 'proposed' && r.driverStatus == 'accepted' && r.seats.any((s) => s.active)) {
        r.status = 'confirmed';
      }
    }
  }

  bool _involvesMe(DemoRide r) {
    final seat = r.seatOf(demoMeId);
    return r.driverIsMe || (seat != null && seat.status != 'declined');
  }

  Proposal _proposal(DemoRide r) {
    final mine = r.seatOf(demoMeId);
    final driver = demoPeople[r.driverId];
    PublicPerson person(DemoSeat s) => PublicPerson(
      userId: s.personId,
      firstName: _firstName(s.personId),
      reliabilityScore: _score(s.personId),
      detourMinutes: s.detourMinutes,
      status: s.status,
    );
    return Proposal(
      id: r.id,
      day: r.day,
      direction: r.direction,
      time: r.time,
      isDriver: r.driverIsMe,
      myStatus: r.driverIsMe ? r.driverStatus : (mine?.status ?? 'proposed'),
      rideStatus: r.status,
      seatsTotal: r.seatsTotal,
      seatsTaken: r.activeSeats.length,
      detourMinutes: r.driverIsMe
          ? r.seats.fold(0, (sum, s) => sum + (s.active ? s.detourMinutes : 0))
          : (mine?.detourMinutes ?? 0),
      driver: driver == null
          ? null
          : PublicPerson(
              userId: driver.id,
              firstName: driver.firstName,
              reliabilityScore: driver.score,
              detourMinutes: mine?.detourMinutes ?? 0,
              status: r.driverStatus,
            ),
      passengers: r.driverIsMe
          ? [for (final s in r.seats.where((s) => s.status != 'declined')) person(s)]
          : const [],
    );
  }

  DemoRide _ride(String id) {
    final r = _rides[id];
    if (r == null) throw const ApiException('not_found', '', statusCode: 404);
    return r;
  }

  @override
  Future<List<Proposal>> week(String week) async {
    await _wait();
    _me;
    _settle();
    return [
      for (final r in _rides.values)
        if (!_hidden.contains(r.id) && _involvesMe(r) && isoWeekOf(r.day) == week) _proposal(r),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  Future<Proposal> accept(String id) async {
    await _wait();
    _settle();
    final r = _ride(id);
    if (r.status != 'proposed' && r.status != 'confirmed') {
      throw const ApiException('ride_unavailable', '', statusCode: 409);
    }
    if (r.driverIsMe) {
      r.driverStatus = 'accepted';
    } else {
      final seat = r.seatOf(demoMeId);
      if (seat == null || seat.status == 'proposed') {
        if (balanceCents < _maxPrice(r)) {
          throw const ApiException('insufficient_funds', '', statusCode: 402);
        }
      }
      if (seat == null) {
        // Voiture choisie par Camille : demande de place, acceptée par le conducteur peu après.
        r.seats.add(
          DemoSeat(demoMeId, 'requested', detourMinutes: 4)
            ..autoAcceptAt = _now.add(const Duration(seconds: 15)),
        );
        // Sa proposition précédente sur le même créneau est retirée.
        for (final other in _rides.values.where(
          (o) => o.id != r.id && o.day == r.day && o.direction == r.direction,
        )) {
          final s = other.seatOf(demoMeId);
          if (s != null && s.status == 'proposed') s.status = 'declined';
        }
      } else if (seat.status == 'proposed') {
        seat.status = 'accepted';
      }
    }
    _settle();
    return _proposal(r);
  }

  @override
  Future<void> decline(String id) async {
    await _wait();
    final r = _ride(id);
    if (r.driverIsMe) {
      r
        ..driverStatus = 'declined'
        ..status = 'cancelled';
    } else {
      r.seatOf(demoMeId)?.status = 'declined';
    }
    _hidden.add(id);
  }

  @override
  Future<Proposal> answerRequest(String rideId, String userId, {required bool approve}) async {
    await _wait();
    final r = _ride(rideId);
    final seat = r.seatOf(userId);
    if (seat == null || seat.status != 'requested') {
      throw const ApiException('not_found', '', statusCode: 404);
    }
    seat.status = approve ? 'accepted' : 'declined';
    _settle();
    return _proposal(r);
  }

  /// Autres voitures du même créneau (conducteurs fictifs), créées à la demande.
  List<JoinableRide> _joinable(DateTime day, Direction direction, DateTime time) {
    final result = <JoinableRide>[];
    for (final (driverId, offset) in [('lea', -10), ('ines', 5), ('lucas', 20)]) {
      if (driverId == 'ines') continue; // Inès est passagère.
      final id = 'demo-join-${day.month}-${day.day}-${direction.wire}-$driverId';
      final r = _rides.putIfAbsent(
        id,
        () => DemoRide(
          id: id,
          day: day,
          direction: direction,
          time: time.add(Duration(minutes: offset)),
          driverId: driverId,
          driverStatus: 'accepted',
          consumption: driverId == 'lucas' ? 9.5 : 5.8,
          seats: [],
        ),
      );
      if (r.seatOf(demoMeId) != null) continue;
      final driver = demoPeople[driverId]!;
      result.add(
        JoinableRide(
          rideId: r.id,
          day: r.day,
          direction: r.direction,
          time: r.time,
          seatsLeft: r.seatsTotal - r.activeSeats.length,
          driver: PublicPerson(
            userId: driver.id,
            firstName: driver.firstName,
            reliabilityScore: driver.score,
            detourMinutes: driverId == 'lucas' ? 9 : 4,
            status: 'accepted',
          ),
        ),
      );
    }
    return result;
  }

  @override
  Future<List<JoinableRide>> alternatives(String id) async {
    await _wait();
    final r = _ride(id);
    return _joinable(r.day, r.direction, r.time).where((j) => j.rideId != id).toList();
  }

  int _searches = 0;

  @override
  Future<List<JoinableRide>> search({
    required DateTime day,
    required Direction direction,
    String? time,
  }) async {
    await _wait();
    if (++_searches > 10) {
      throw const ApiException('search_quota_exceeded', '', statusCode: 429);
    }
    final parts = (time ?? (direction == Direction.toCampus ? '08:00' : '17:00')).split(':');
    final at = DateTime(day.year, day.month, day.day, int.parse(parts[0]), int.parse(parts[1]));
    return _joinable(DateTime(day.year, day.month, day.day), direction, at);
  }

  // --- Trajets confirmés ---

  RideDetails _details(DemoRide r) {
    final path = _path(r);
    final road = _road(path);
    final total = _lineLength(road);
    // 35 km/h de moyenne sur la route réelle : heures de passage.
    const speed = 35 * 1000 / 3600;
    var travelled = 0.0;
    final stops = <RideStop>[];
    for (final (i, p) in path.indexed) {
      if (i > 0) travelled += _lineLength(_leg(path[i - 1], p));
      final eta = r.direction == Direction.toCampus
          ? r.time.subtract(Duration(seconds: (total - travelled) ~/ speed))
          : r.time.add(Duration(seconds: travelled ~/ speed));
      final userId = p.userId;
      final seat = userId == null ? null : r.seatOf(userId);
      final isDriverStop = userId == r.driverId;
      // Entre passagers : prénom et secteur seulement (cahier §4).
      final coPassenger = !r.driverIsMe && userId != null && !isDriverStop && userId != demoMeId;
      stops.add(
        RideStop(
          order: i,
          kind: userId == null
              ? StopKind.campus
              : (isDriverStop ? StopKind.driver : StopKind.passenger),
          userId: userId,
          firstName: userId == null ? null : _firstName(userId),
          lastName: userId == null || coPassenger ? null : _lastName(userId),
          label: coPassenger && !p.meeting ? '' : p.label,
          lat: coPassenger && !p.meeting ? (p.lat * 100).round() / 100 : p.lat,
          lon: coPassenger && !p.meeting ? (p.lon * 100).round() / 100 : p.lon,
          eta: eta,
          isMeetingPoint: p.meeting,
          pickedUp: seat?.pickedUp ?? false,
          presenceValidated: seat?.presenceValidated ?? false,
          arrived: seat?.arrived ?? false,
          ended: seat?.ended ?? false,
        ),
      );
    }
    final price = _priceOf(r);
    final mine = r.seatOf(demoMeId);
    return RideDetails(
      id: r.id,
      day: r.day,
      direction: r.direction,
      time: r.time,
      status: r.status,
      isDriver: r.driverIsMe,
      myStatus: r.driverIsMe ? 'accepted' : (mine?.status ?? 'accepted'),
      routeEstimated: false,
      // Passagère : le tracé ne trahit pas le domicile d'un autre passager (cahier §4).
      route: [
        for (final point in road)
          if (r.driverIsMe ||
              path.every(
                (p) =>
                    p.userId == null ||
                    p.userId == demoMeId ||
                    p.userId == r.driverId ||
                    p.meeting ||
                    demoDistance(p.lat, p.lon, point.$1, point.$2) > 500,
              ))
            point,
      ],
      stops: stops,
      distanceM: total.round(),
      durationS: (total / speed).round(),
      price: RidePrice(
        totalCostCents: price.cost,
        persons: price.persons,
        shareCents: price.share,
        commissionCents: demoCommissionCents,
        youPayCents: r.driverIsMe ? null : price.youPay,
        youReceiveCents: r.driverIsMe ? price.youReceive : null,
      ),
    );
  }

  @override
  Future<RideDetails> ride(String id) async {
    await _wait();
    _settle();
    final r = _rides[id];
    if (r == null || !_involvesMe(r)) throw const ApiException('forbidden', '', statusCode: 403);
    if (!{'confirmed', 'in_progress', 'completed'}.contains(r.status)) {
      throw const ApiException('ride_not_confirmed', '', statusCode: 409);
    }
    return _details(r);
  }

  @override
  Future<void> setMeetingPoint(String id, MeetingPoint? point) async {
    await _wait();
    final seat = _ride(id).seatOf(demoMeId);
    if (seat == null) throw const ApiException('forbidden', '', statusCode: 403);
    final home = _pointOf(demoMeId);
    if (point != null && demoDistance(home.lat, home.lon, point.lat, point.lon) > 2000) {
      throw const ApiException('meeting_point_too_far', '', statusCode: 422);
    }
    seat.meetingPoint = point == null ? null : (label: point.label, lat: point.lat, lon: point.lon);
  }

  @override
  Future<Suggestions> suggestions(String id) async {
    await _wait();
    final r = _ride(id);
    final taken = r.seats.map((s) => s.personId).toSet();
    final current = _priceOf(r);
    return Suggestions(
      seatsLeft: r.seatsTotal - r.activeSeats.length,
      currentPassengerPaysCents: current.youPay,
      items: [
        for (final (personId, detour, within) in [('lea', 5, true), ('theo', 14, false)])
          if (!taken.contains(personId))
            () {
              final simulated = _priceOf(r, persons: r.activeSeats.length + 2);
              return Suggestion(
                person: PublicPerson(
                  userId: personId,
                  firstName: _firstName(personId),
                  reliabilityScore: _score(personId),
                  detourMinutes: detour,
                  status: 'suggested',
                ),
                withinDetourLimit: within,
                shareCents: simulated.share,
                passengerPaysCents: simulated.youPay,
              );
            }(),
      ],
    );
  }

  @override
  Future<Proposal> invite(String id, String userId) async {
    await _wait();
    final r = _ride(id);
    if (r.activeSeats.length >= r.seatsTotal) {
      throw const ApiException('ride_full', '', statusCode: 409);
    }
    r.seats.add(
      DemoSeat(userId, 'proposed', detourMinutes: 5)
        ..autoAcceptAt = _now.add(const Duration(seconds: 20)),
    );
    return _proposal(r);
  }

  // --- Cycle de vie : départ, prise en charge, présence, clôture ---

  @override
  Future<void> start(String id) async {
    await _wait();
    final r = _ride(id);
    if (!r.driverIsMe) throw const ApiException('forbidden', '', statusCode: 403);
    if (r.status == 'in_progress') return;
    if (r.status != 'confirmed') {
      throw const ApiException('ride_not_confirmed', '', statusCode: 409);
    }
    for (final s in r.seats.where((s) => s.status == 'requested')) {
      s.status = 'declined';
    }
    r.status = 'in_progress';
    _sims[id] = _Sim();
  }

  @override
  Future<void> pickedUp(String id, String userId) async {
    await _wait();
    final r = _ride(id);
    final seat = r.seatOf(userId);
    if (!r.driverIsMe || seat == null || r.status != 'in_progress') {
      throw const ApiException('forbidden', '', statusCode: 403);
    }
    // Démo : les téléphones sont « proches » à la montée, la présence se valide aussi.
    seat
      ..pickedUp = true
      ..presenceValidated = true;
    _emit(id, LivePickedUp(userId));
    _emit(id, LivePresence(userId));
  }

  @override
  Future<NavigationPlan> navigation(String id) async {
    await _wait();
    final details = _details(_ride(id));
    final passengers = details.stops.where((s) => s.kind == StopKind.passenger).toList();
    final destination = details.stops.last;
    final stops = [...passengers, destination];
    final remaining = stops.where((s) => !s.pickedUp).toList();
    String coord(RideStop s) => '${s.lat.toStringAsFixed(6)},${s.lon.toStringAsFixed(6)}';
    final last = remaining.isEmpty ? destination : remaining.last;
    final waypoints = remaining.length <= 1
        ? <RideStop>[]
        : remaining.sublist(0, remaining.length - 1);
    return NavigationPlan(
      stops: [
        for (final (i, s) in stops.indexed)
          NavigationStop(
            order: i + 1,
            isDestination: s.kind != StopKind.passenger,
            userId: s.kind == StopKind.passenger ? s.userId : null,
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
  Future<void> presence(String id) async {
    await _wait();
    final r = _ride(id);
    final seat = r.seatOf(demoMeId);
    if (seat == null || r.status != 'in_progress') {
      throw const ApiException('ride_not_started', '', statusCode: 409);
    }
    final sim = _sims[id];
    // Conducteur encore loin : comme le serveur, refus (les téléphones doivent être proches).
    if (sim == null || sim.travelled < sim.pickupAt - 300) {
      throw const ApiException('presence_not_confirmed', '', statusCode: 409);
    }
    _boardMe(r);
  }

  void _boardMe(DemoRide r) {
    final seat = r.seatOf(demoMeId)!;
    if (seat.presenceValidated) return;
    seat
      ..presenceValidated = true
      ..pickedUp = true;
    _emit(r.id, const LivePresence(demoMeId));
    _emit(r.id, const LivePickedUp(demoMeId));
  }

  @override
  Future<void> finish(String id) async {
    await _wait();
    final r = _ride(id);
    if (r.status == 'completed') return;
    if (r.status != 'in_progress') {
      throw const ApiException('ride_not_started', '', statusCode: 409);
    }
    if (r.driverIsMe) return _close(r);
    final seat = r.seatOf(demoMeId)!;
    if (!seat.presenceValidated) {
      throw const ApiException('not_on_board', '', statusCode: 409);
    }
    seat.ended = true;
    _closeLive(id, 4410);
    _close(r);
  }

  /// Clôture : prix final partagé entre les présents, payé par les passagers arrivés.
  void _close(DemoRide r) {
    if (r.status == 'completed') return;
    r.status = 'completed';
    final present = r.activeSeats.where((s) => s.presenceValidated).toList();
    final price = _priceOf(r, persons: present.length + 1);
    final at = _now;
    if (r.driverIsMe) {
      final paying = present.where((s) => s.arrived).length;
      if (paying > 0) {
        balanceCents += price.share * paying;
        _entry('ride_credit', price.share * paying, at);
      }
    } else {
      final held = _held.remove(r.id) ?? 0;
      heldCents -= held;
      balanceCents += held;
      final me = r.seatOf(demoMeId)!;
      if (me.presenceValidated && me.arrived) {
        final paid = min(price.youPay, held == 0 ? price.youPay : held);
        balanceCents -= paid;
        _entry('ride_charge', -paid, at);
      }
    }
    for (final s in r.activeSeats.where((s) => !s.presenceValidated)) {
      s.status = 'cancelled';
    }
    _emit(r.id, const LiveStatus('completed'));
    _closeLive(r.id, 4410);
    _completedExtra++;
  }

  // --- Suivi en direct simulé ---

  final Map<String, _Sim> _sims = {};
  final Map<String, List<_DemoLiveConnection>> _live = {};

  Future<LiveConnection> _connectLive(String rideId) async {
    await _wait();
    final r = _rides[rideId];
    final connection = _DemoLiveConnection(() => _detach(rideId));
    if (r == null || r.status != 'in_progress') {
      connection.serverClose(r?.status == 'completed' ? 4410 : 4409);
      return connection;
    }
    if (!r.driverIsMe && (r.seatOf(demoMeId)?.ended ?? false)) {
      connection.serverClose(4410);
      return connection;
    }
    _live.putIfAbsent(rideId, () => []).add(connection);
    final sim = _sims.putIfAbsent(rideId, _Sim.new);
    if (!r.driverIsMe && sim.pickupAt == 0) {
      // Le conducteur part 1,6 km avant l'arrêt de Camille.
      final path = _path(r);
      final index = path.indexWhere((p) => p.userId == demoMeId);
      sim.pickupAt = _lineLength(_road(path.sublist(0, index + 1)));
      sim.travelled = max(0, sim.pickupAt - 1600);
    }
    scheduleMicrotask(() {
      connection.emit(const LiveReady());
      _step(r, advance: false);
    });
    sim.timer ??= Timer.periodic(tick, (_) => _step(r));
    return connection;
  }

  void _detach(String rideId) {
    _live[rideId]?.removeWhere((c) => c.closed);
    if (_live[rideId]?.isEmpty ?? true) {
      _sims[rideId]?.timer?.cancel();
      _sims[rideId]?.timer = null;
    }
  }

  void _emit(String rideId, LiveEvent event) {
    for (final c in List.of(_live[rideId] ?? const <_DemoLiveConnection>[])) {
      c.emit(event);
    }
  }

  void _closeLive(String rideId, int code) {
    _sims[rideId]?.timer?.cancel();
    _sims[rideId]?.timer = null;
    for (final c in List.of(_live[rideId] ?? const <_DemoLiveConnection>[])) {
      c.serverClose(code);
    }
    _live.remove(rideId);
  }

  void _closeAllLive() {
    for (final id in List.of(_live.keys)) {
      _closeLive(id, 1000);
    }
  }

  /// Un pas de simulation : le conducteur avance (Camille passagère) ou les passagers
  /// attendent puis arrivent (Camille conductrice).
  void _step(DemoRide r, {bool advance = true}) {
    if (r.status != 'in_progress') return;
    final sim = _sims[r.id]!;
    final now = _now;
    if (!r.driverIsMe) {
      final road = _road(_path(r));
      final total = _lineLength(road);
      if (advance) sim.travelled = min(total, sim.travelled + 280);
      final (lat, lon) = _along(road, sim.travelled);
      _emit(r.id, LivePosition(userId: r.driverId, lat: lat, lon: lon, at: now));
      final me = r.seatOf(demoMeId)!;
      if (sim.travelled < sim.pickupAt) {
        final seconds = ((sim.pickupAt - sim.travelled) / (40 / 3.6)).round();
        _emit(
          r.id,
          LiveEta(
            userId: demoMeId,
            eta: now.add(Duration(seconds: seconds)),
          ),
        );
      } else {
        _boardMe(r);
      }
      if (sim.travelled >= total && !me.arrived) {
        me
          ..arrived = true
          ..ended = true;
        _emit(r.id, const LivePassengerDone(demoMeId, arrived: true));
        _close(r);
      }
      return;
    }
    final waiting = r.activeSeats.where((s) => !s.pickedUp).toList();
    for (final s in waiting) {
      final p = s.meetingPoint ?? _pointOf(s.personId);
      _emit(r.id, LivePosition(userId: s.personId, lat: p.lat, lon: p.lon, at: now));
    }
    if (waiting.isNotEmpty || !advance) return;
    // Tout le monde est à bord : chacun arrive à son tour, puis le trajet se clôt.
    if (++sim.afterBoarding < 4) return;
    final next = r.activeSeats.where((s) => !s.arrived).firstOrNull;
    if (next != null) {
      next
        ..arrived = true
        ..ended = true;
      _emit(r.id, LivePassengerDone(next.personId, arrived: true));
    } else {
      _close(r);
    }
  }

  /// Point à `meters` du départ, le long du tracé routier.
  (double, double) _along(List<(double, double)> line, double meters) {
    var left = meters;
    for (var i = 1; i < line.length; i++) {
      final (aLat, aLon) = line[i - 1];
      final (bLat, bLon) = line[i];
      final d = demoDistance(aLat, aLon, bLat, bLon);
      if (left <= d && d > 0) {
        final f = left / d;
        return (aLat + (bLat - aLat) * f, aLon + (bLon - aLon) * f);
      }
      left -= d;
    }
    return line.last;
  }

  // --- Portefeuille ---

  final Set<String> _keys = {};
  DateTime? _lastPayout;

  Wallet get _wallet =>
      Wallet(balanceCents: balanceCents, heldCents: heldCents, history: List.of(_history));

  @override
  Future<Wallet> wallet() async {
    await _wait();
    _me;
    return _wallet;
  }

  @override
  Future<Wallet> topup(int amountCents, String idempotencyKey) async {
    await _wait();
    if (amountCents < 1000) throw const ApiException('topup_too_small', '', statusCode: 400);
    if (_keys.add(idempotencyKey)) {
      balanceCents += amountCents;
      _entry('topup', amountCents, _now);
    }
    return _wallet;
  }

  @override
  Future<Wallet> payout(PayoutRequest request, String idempotencyKey) async {
    await _wait();
    if (_keys.contains(idempotencyKey)) return _wallet;
    if (request.amountCents < 1000) {
      throw const ApiException('payout_too_small', '', statusCode: 400);
    }
    if (!_validIban(request.iban)) throw const ApiException('iban_invalid', '', statusCode: 400);
    if (request.amountCents > balanceCents) {
      throw const ApiException('insufficient_funds', '', statusCode: 409);
    }
    final last = _lastPayout;
    if (last != null && _now.difference(last) < const Duration(days: 7)) {
      throw const ApiException('payout_too_soon', '', statusCode: 429);
    }
    _keys.add(idempotencyKey);
    _lastPayout = _now;
    balanceCents -= request.amountCents;
    _entry('payout', -request.amountCents, _now);
    return _wallet;
  }

  /// Contrôle mod 97 (ISO 13616), comme le serveur.
  static bool _validIban(String raw) {
    final iban = raw.replaceAll(' ', '').toUpperCase();
    if (!RegExp(r'^[A-Z]{2}\d{2}[A-Z0-9]{11,30}$').hasMatch(iban)) return false;
    final moved = iban.substring(4) + iban.substring(0, 4);
    var rest = 0;
    for (final unit in moved.codeUnits) {
      final digits = unit >= 65 ? '${unit - 55}' : String.fromCharCode(unit);
      for (final d in digits.codeUnits) {
        rest = (rest * 10 + d - 48) % 97;
      }
    }
    return rest == 1;
  }

  // --- Confiance ---

  final List<ReliabilityEvent> _events = [];
  final Map<String, int> _given = {};
  final Map<String, List<Dispute>> _disputes = {};
  int _cancellations = 1;
  int _completedExtra = 0;

  CancelTier _tier(DateTime rideTime) {
    final hours = rideTime.difference(_now).inMinutes / 60;
    return hours >= 24 ? CancelTier.early : (hours >= 2 ? CancelTier.medium : CancelTier.late);
  }

  @override
  Future<CancellationInfo> cancellation(String rideId) async {
    await _wait();
    final r = _ride(rideId);
    return CancellationInfo(isDriver: r.driverIsMe, tier: _tier(r.time));
  }

  @override
  Future<CancelTier> cancel(String rideId) async {
    await _wait();
    final r = _ride(rideId);
    final tier = _tier(r.time);
    if (r.driverIsMe) {
      r.status = 'cancelled';
    } else {
      final seat = r.seatOf(demoMeId);
      if (seat == null || (r.status == 'in_progress' && seat.presenceValidated)) {
        throw const ApiException('ride_unavailable', '', statusCode: 409);
      }
      seat.status = 'cancelled';
      final held = _held.remove(r.id) ?? 0;
      heldCents -= held;
      balanceCents += held;
      _closeLive(rideId, 4403);
      if (r.status == 'confirmed' && r.activeSeats.isEmpty) r.status = 'proposed';
    }
    _hidden.add(rideId);
    _cancellations++;
    _events.insert(
      0,
      ReliabilityEvent(
        kind: switch (tier) {
          CancelTier.early => ReliabilityEventKind.cancelEarly,
          CancelTier.medium => ReliabilityEventKind.cancelMedium,
          CancelTier.late => ReliabilityEventKind.cancelLate,
        },
        rideId: rideId,
        day: r.day,
        createdAt: _now,
        disputeReason: DisputeReason.cancellationPenalty,
      ),
    );
    return tier;
  }

  @override
  Future<RideRatings> ratings(String rideId) async {
    await _wait();
    final r = _ride(rideId);
    final people = r.driverIsMe
        ? [
            for (final s in r.activeSeats.where((s) => s.presenceValidated))
              RatingTarget(userId: s.personId, firstName: _firstName(s.personId), isDriver: false),
          ]
        : [RatingTarget(userId: r.driverId, firstName: _firstName(r.driverId), isDriver: true)];
    return RideRatings(
      open: r.status == 'completed',
      people: [
        for (final p in people)
          if (_given['$rideId|${p.userId}'] case final stars?) p.withStars(stars) else p,
      ],
    );
  }

  @override
  Future<void> rate(String rideId, String userId, int stars) async {
    await _wait();
    final key = '$rideId|$userId';
    if (_given.containsKey(key)) throw const ApiException('already_rated', '', statusCode: 409);
    _given[key] = stars;
  }

  @override
  Future<Reliability> reliability() async {
    await _wait();
    final penalties = _events.length;
    return Reliability(
      score: max(0.4, 0.95 - 0.04 * penalties),
      windowDays: 180,
      completedRides: 14 + _completedExtra,
      cancellations: _cancellations,
      noShows: 0,
      ratingsCount: 11 + _given.length,
      averageStars: 4.7,
      events: List.of(_events),
    );
  }

  @override
  Future<List<Dispute>> disputes(String rideId) async {
    await _wait();
    return List.of(_disputes[rideId] ?? const []);
  }

  @override
  Future<Dispute> openDispute(String rideId, DisputeReason reason, String? message) async {
    await _wait();
    final list = _disputes.putIfAbsent(rideId, () => []);
    if (list.any((d) => d.reason == reason)) {
      throw const ApiException('dispute_exists', '', statusCode: 409);
    }
    final dispute = switch (reason) {
      DisputeReason.cancellationPenalty => Dispute(
        id: _id('dispute'),
        reason: reason,
        level: 1,
        decision: DisputeDecision.upheld,
        explanation: 'penalty_matches_timestamps',
      ),
      DisputeReason.markedAbsent => Dispute(
        id: _id('dispute'),
        reason: reason,
        level: 1,
        decision: DisputeDecision.corrected,
        explanation: 'presence_evidence_found',
      ),
      _ => Dispute(
        id: _id('dispute'),
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
    await _wait();
    for (final list in _disputes.values) {
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
  Future<void> report(String userId, ReportReason reason, String? message) => _wait();

  // --- Messagerie ---

  final Map<String, Conversation> _conversations = {};
  final Map<String, List<ChatMessage>> _messages = {};
  final List<_DemoSocket> _sockets = [];

  static const _replies = [
    'Ça marche, à tout à l’heure.',
    'Je suis devant dans 5 minutes.',
    'Super, merci !',
    'Je t’attends au point de rendez-vous.',
    'Pas de souci.',
  ];

  ChatMember _member(String id) => ChatMember(userId: id, firstName: _firstName(id));

  void _seedChats() {
    final live = _rides['demo-live']!;
    final drive = _rides['demo-drive']!;
    _conversation(
      'conv-live',
      ConversationKind.ride,
      ['nathan'],
      ride: live,
      messages: [
        ('nathan', 'Salut Camille, je pars de Sévrier, j’arrive vers chez toi dans 10 min.', 14),
        (demoMeId, 'Parfait, je descends.', 12),
      ],
    );
    _conversation(
      'conv-drive',
      ConversationKind.ride,
      ['ines', 'hugo'],
      ride: drive,
      messages: [
        ('ines', 'Je finis à 17 h, je te retrouve au parking ?', 90),
        ('hugo', 'Moi aussi, merci pour le retour !', 80),
      ],
      unread: 2,
    );
    _conversation(
      'conv-lea',
      ConversationKind.direct,
      ['lea'],
      messages: [('lea', 'Tu montes avec moi demain ? Je passe à 7 h 40.', 200)],
      unread: 1,
    );
    _conversation(
      'conv-group',
      ConversationKind.group,
      ['nathan', 'ines', 'hugo'],
      title: 'Covoit’ Seynod',
      messages: [('hugo', 'Quelqu’un pour vendredi soir ?', 60 * 26)],
    );
  }

  void _conversation(
    String id,
    ConversationKind kind,
    List<String> others, {
    DemoRide? ride,
    String? title,
    List<(String, String, int)> messages = const [],
    int unread = 0,
  }) {
    final list = [
      for (final (sender, body, minutesAgo) in messages)
        ChatMessage(
          id: _id('msg'),
          conversationId: id,
          senderId: sender,
          body: body,
          createdAt: _now.subtract(Duration(minutes: minutesAgo)).toUtc(),
        ),
    ];
    _messages[id] = list;
    _conversations[id] = Conversation(
      id: id,
      kind: kind,
      title: title,
      rideId: ride?.id,
      rideDay: ride?.day,
      rideToCampus: ride == null ? null : ride.direction == Direction.toCampus,
      archived: false,
      unread: unread,
      members: [_member(demoMeId), for (final o in others) _member(o)],
      lastMessage: list.lastOrNull,
    );
  }

  @override
  Future<List<Conversation>> conversations() async {
    await _wait();
    final list = _conversations.values.toList()
      ..sort(
        (a, b) => (b.lastMessage?.createdAt ?? DateTime(2000)).compareTo(
          a.lastMessage?.createdAt ?? DateTime(2000),
        ),
      );
    return list;
  }

  @override
  Future<Conversation> conversation(String id) async {
    await _wait();
    final c = _conversations[id];
    if (c == null) throw const ApiException('not_found', '', statusCode: 404);
    return c;
  }

  @override
  Future<Conversation> rideConversation(String rideId) async {
    await _wait();
    final existing = _conversations.values.where((c) => c.rideId == rideId).firstOrNull;
    if (existing != null) return existing;
    final r = _ride(rideId);
    final others = {
      if (!r.driverIsMe) r.driverId,
      for (final s in r.activeSeats)
        if (s.personId != demoMeId) s.personId,
    }.toList();
    final id = _id('conv');
    _conversation(id, ConversationKind.ride, others, ride: r);
    return _conversations[id]!;
  }

  @override
  Future<List<ChatMember>> contacts() async {
    await _wait();
    return [
      for (final id in ['nathan', 'ines', 'hugo', 'lea']) _member(id),
    ];
  }

  @override
  Future<Conversation> createDirect(String userId) async {
    await _wait();
    final existing = _conversations.values.where(
      (c) => c.kind == ConversationKind.direct && c.members.any((m) => m.userId == userId),
    );
    if (existing.isNotEmpty) return existing.first;
    final id = _id('conv');
    _conversation(id, ConversationKind.direct, [userId]);
    return _conversations[id]!;
  }

  @override
  Future<Conversation> createGroup(String title, List<String> userIds) async {
    await _wait();
    final id = _id('conv');
    _conversation(id, ConversationKind.group, userIds, title: title);
    return _conversations[id]!;
  }

  @override
  Future<List<ChatMessage>> messages(String id, {DateTime? before, String? beforeId}) async {
    await _wait();
    final all = (_messages[id] ?? const <ChatMessage>[]).where(
      (m) => before == null || m.createdAt.isBefore(before),
    );
    return all.toList().reversed.take(50).toList();
  }

  @override
  Future<ChatMessage> send(String id, String body) async {
    await _wait();
    final c = _conversations[id];
    if (c == null) throw const ApiException('not_found', '', statusCode: 404);
    final message = ChatMessage(
      id: _id('msg'),
      conversationId: id,
      senderId: demoMeId,
      body: body,
      createdAt: _now.toUtc(),
    );
    _messages.putIfAbsent(id, () => []).add(message);
    _conversations[id] = c.copyWith(lastMessage: message);
    // Quelqu'un répond quelques secondes plus tard.
    final other = c.members.where((m) => m.userId != demoMeId).firstOrNull;
    if (other != null) {
      Timer(const Duration(seconds: 3), () {
        final reply = ChatMessage(
          id: _id('msg'),
          conversationId: id,
          senderId: other.userId,
          body: _replies[_counter % _replies.length],
          createdAt: _now.toUtc(),
        );
        _messages[id]?.add(reply);
        final current = _conversations[id];
        if (current == null) return;
        _conversations[id] = current.copyWith(unread: current.unread + 1, lastMessage: reply);
        for (final s in _sockets.where((s) => !s.closed)) {
          s.controller.add(reply);
        }
      });
    }
    return message;
  }

  @override
  Future<void> markRead(String id) async {
    final c = _conversations[id];
    if (c != null) _conversations[id] = c.copyWith(unread: 0);
  }

  @override
  Future<void> leave(String id) async {
    await _wait();
    _conversations.remove(id);
  }

  Future<UserSocketConnection> _connectSocket() async {
    final socket = _DemoSocket();
    _sockets.add(socket);
    return socket;
  }

  // --- Notifications ---

  NotificationPreferences _preferences = const NotificationPreferences();

  @override
  Future<void> registerDevice(String token) async {}

  @override
  Future<void> unregisterDevice(String token) async {}

  @override
  Future<NotificationPreferences> preferences() async {
    await _wait();
    return _preferences;
  }

  @override
  Future<NotificationPreferences> setPreferences(NotificationPreferences prefs) async {
    await _wait();
    return _preferences = prefs;
  }

  // --- Compte (RGPD) ---

  @override
  Future<Uint8List> exportData() async {
    await _wait();
    final me = _me;
    return Uint8List.fromList(
      utf8.encode(
        const JsonEncoder.withIndent('  ').convert({
          'demo': true,
          'profile': {
            'universityEmail': me.email,
            'firstName': me.firstName,
            'lastName': me.lastName,
            'home': me.home?.address,
          },
          'rides': [
            for (final r in _rides.values.where(_involvesMe))
              {
                'id': r.id,
                'day': r.day.toIso8601String().substring(0, 10),
                'direction': r.direction.wire,
                'status': r.status,
              },
          ],
          'wallet': {
            'balanceCents': balanceCents,
            'history': [
              for (final e in _history)
                {'kind': e.kind, 'amountCents': e.amountCents, 'at': e.at.toIso8601String()},
            ],
          },
        }),
      ),
    );
  }

  @override
  Future<void> deleteAccount(String password) async {
    await _wait();
    final me = _me;
    if (password != me.password) {
      throw const ApiException('invalid_password', '', statusCode: 401);
    }
    if (_rides.values.any((r) => r.status == 'in_progress' && _involvesMe(r))) {
      throw const ApiException('ride_in_progress', '', statusCode: 409);
    }
    if (balanceCents + heldCents > 0) {
      throw const ApiException('wallet_not_empty', '', statusCode: 409);
    }
    _closeAllLive();
    _account = null;
    _signedIn = false;
  }

  /// Fin de la démo : plus aucune minuterie.
  void dispose() {
    _closeAllLive();
    for (final s in _sims.values) {
      s.timer?.cancel();
    }
    for (final s in _sockets) {
      unawaited(s.close());
    }
  }
}

class _DemoLiveConnector implements LiveConnector {
  _DemoLiveConnector(this._backend);

  final DemoBackend _backend;

  @override
  Future<LiveConnection> connect(String rideId) => _backend._connectLive(rideId);
}

class _DemoSocketConnector implements UserSocketConnector {
  _DemoSocketConnector(this._backend);

  final DemoBackend _backend;

  @override
  Future<UserSocketConnection> connect() => _backend._connectSocket();
}

class _Sim {
  double travelled = 0;
  double pickupAt = 0;
  int afterBoarding = 0;
  Timer? timer;
}

class _DemoLiveConnection implements LiveConnection {
  _DemoLiveConnection(this._onClose);

  final void Function() _onClose;
  final _events = StreamController<LiveEvent>.broadcast();
  final _closed = Completer<int?>();
  bool closed = false;

  void emit(LiveEvent event) {
    if (!closed) _events.add(event);
  }

  void serverClose(int code) {
    if (closed) return;
    closed = true;
    if (!_closed.isCompleted) _closed.complete(code);
    _onClose();
  }

  @override
  Stream<LiveEvent> get events => _events.stream;

  @override
  Future<int?> get closeCode => _closed.future;

  @override
  void sendPosition({required double lat, required double lon, required DateTime at}) {}

  @override
  Future<void> close() async {
    closed = true;
    if (!_closed.isCompleted) _closed.complete(null);
    _onClose();
    await _events.close();
  }
}

class _DemoSocket implements UserSocketConnection {
  final controller = StreamController<ChatMessage>.broadcast();
  final _done = Completer<int?>();
  bool closed = false;

  @override
  Future<void> get ready => Future.value();

  @override
  Stream<ChatMessage> get messages => controller.stream;

  @override
  Future<int?> get done => _done.future;

  @override
  Future<void> close() async {
    closed = true;
    if (!_done.isCompleted) _done.complete(1000);
    await controller.close();
  }
}

class _DemoAccount {
  _DemoAccount(this.email, this.firstName, this.lastName, this.password);

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

  Me toMe(DateTime today) {
    final next = OnboardingStep.values.where((s) => !steps.containsKey(s)).firstOrNull;
    return Me(
      id: demoMeId,
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
