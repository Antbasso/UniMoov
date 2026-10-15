import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/session_controller.dart';
import '../data/profile_api.dart';
import '../domain/me.dart';

/// Profil de l'utilisateur connecté (`null` hors session). Chaque action renvoie le profil
/// à jour du serveur ; les erreurs ([ApiException]) remontent à l'écran qui les affiche.
class MeController extends AsyncNotifier<Me?> {
  ProfileApi get _api => ref.read(profileApiProvider);

  @override
  Future<Me?> build() async {
    final session = await ref.watch(sessionProvider.future);
    if (session != SessionStatus.signedIn) return null;
    return ref.watch(profileApiProvider).getMe();
  }

  Future<void> _apply(Future<Me> Function() action) async {
    state = AsyncData(await action());
  }

  Future<void> setAddress(String address) => _apply(() => _api.setAddress(address));
  Future<void> setVehicle(Vehicle vehicle) => _apply(() => _api.setVehicle(vehicle));
  Future<void> setRoleMode(RoleMode mode) => _apply(() => _api.setRoleMode(mode));
  Future<void> updateNames({String? firstName, String? lastName}) =>
      _apply(() => _api.updateNames(firstName: firstName, lastName: lastName));
  Future<void> setStep(OnboardingStep step, StepStatus status) =>
      _apply(() => _api.setStep(step, status));

  Future<void> removeVehicle() async {
    await _api.removeVehicle();
    state = AsyncData(await _api.getMe());
  }

  Future<void> reload() async {
    state = await AsyncValue.guard(_api.getMe);
  }
}

final meProvider = AsyncNotifierProvider<MeController, Me?>(
  MeController.new,
  retry: (retryCount, error) => null,
);

/// Pauses programmées ; chaque modification rafraîchit aussi `pausedToday` du profil.
class PausesController extends AsyncNotifier<List<Pause>> {
  ProfileApi get _api => ref.read(profileApiProvider);

  @override
  Future<List<Pause>> build() => ref.watch(profileApiProvider).listPauses();

  Future<void> add(DateTime startsOn, DateTime endsOn, int? everyWeeks) async {
    await _api.addPause(startsOn, endsOn, everyWeeks);
    state = AsyncData(await _api.listPauses());
    await ref.read(meProvider.notifier).reload();
  }

  Future<void> remove(String id) async {
    await _api.removePause(id);
    state = AsyncData(await _api.listPauses());
    await ref.read(meProvider.notifier).reload();
  }
}

final pausesProvider = AsyncNotifierProvider.autoDispose<PausesController, List<Pause>>(
  PausesController.new,
  retry: (retryCount, error) => null,
);
