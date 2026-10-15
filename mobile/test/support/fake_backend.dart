import 'package:unimoov/core/api/api_client.dart';
import 'package:unimoov/features/auth/data/auth_api.dart';
import 'package:unimoov/features/auth/domain/auth_tokens.dart';
import 'package:unimoov/features/profile/data/profile_api.dart';
import 'package:unimoov/features/profile/domain/me.dart';

/// Backend en mémoire qui reproduit les règles de l'API (docs/api.md) pour les tests de
/// parcours. Il survit à un « redémarrage » de l'app, comme le vrai serveur.
class FakeBackend implements AuthApi, ProfileApi {
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

  /// Accès direct pour préparer un état (tests).
  void seedAccount(
    String email, {
    String firstName = 'Léa',
    Map<OnboardingStep, StepStatus>? steps,
  }) {
    _accounts[email] = _Account(email, firstName, 'Martin', 'motdepasse-solide')
      ..steps.addAll(steps ?? {});
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
    );
  }
}
