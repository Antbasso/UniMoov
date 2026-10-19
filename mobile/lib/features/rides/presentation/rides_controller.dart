import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../proposals/domain/proposal.dart';
import '../../proposals/presentation/proposals_controller.dart';
import '../data/rides_api.dart';
import '../domain/ride.dart';

/// Trajet confirmé (carte, arrêts, prix). Le serveur recalcule le plan à chaque changement.
class RideController extends AsyncNotifier<RideDetails> {
  RideController(this.id);

  final String id;

  @override
  Future<RideDetails> build() => ref.watch(ridesApiProvider).ride(id);

  /// Point de rendez-vous (ou retour à l'adresse avec `null`), puis plan à jour.
  Future<void> setMeetingPoint(MeetingPoint? point) async {
    await ref.read(ridesApiProvider).setMeetingPoint(id, point);
    // La modification est faite : un échec du rechargement ne doit pas la faire passer pour ratée.
    if (ref.mounted) ref.invalidateSelf();
  }

  /// Conducteur : départ (le suivi en direct s'ouvre), passager monté, clôture pour tous.
  /// Passager : présence validée par proximité, fin de son trajet seulement.
  Future<void> start() => _act((api) => api.start(id));
  Future<void> pickedUp(String userId) => _act((api) => api.pickedUp(id, userId));
  Future<void> finish() => _act((api) => api.finish(id));
  Future<void> confirmPresence() => _act((api) => api.presence(id));

  Future<void> _act(Future<void> Function(RidesApi api) action) async {
    await action(ref.read(ridesApiProvider));
    if (!ref.mounted) return;
    ref.invalidateSelf();
    ref.invalidate(navigationProvider(id));
  }
}

/// Tracé d'un trajet proposé ou confirmé (avant confirmation aussi), avec mon temps de trajet
/// et les points de rencontre.
final ridePreviewProvider = FutureProvider.autoDispose.family<RidePreview, String>(
  (ref, id) => ref.watch(ridesApiProvider).preview(id),
  retry: (retryCount, error) => null,
);

/// Parkings publics et aires de covoiturage d'une zone ; vide si le service ne répond pas (la
/// carte reste utilisable : on touche n'importe où).
final meetingSpotsProvider = FutureProvider.autoDispose.family<List<MeetingSpot>, MapBounds>((
  ref,
  bounds,
) async {
  try {
    return await ref.watch(ridesApiProvider).meetingSpots(bounds);
  } on Object {
    return const [];
  }
}, retry: (retryCount, error) => null);

/// Point de rencontre : le passager choisit le sien (avant ou après avoir accepté), le
/// conducteur en propose un, le passager répond. L'aperçu et le trajet sont relus ensuite.
class MeetingPointActions {
  const MeetingPointActions(this._ref);

  final Ref _ref;

  RidesApi get _api => _ref.read(ridesApiProvider);

  Future<void> choose(String rideId, MeetingPoint? point) async {
    await _api.setMeetingPoint(rideId, point);
    _refresh(rideId);
  }

  Future<void> propose(String rideId, String userId, MeetingPoint point) async {
    await _api.proposeMeetingPoint(rideId, userId, point);
    _refresh(rideId);
  }

  Future<void> answer(String rideId, {required bool accept}) async {
    await _api.answerMeetingPoint(rideId, accept: accept);
    _refresh(rideId);
  }

  void _refresh(String rideId) {
    _ref
      ..invalidate(ridePreviewProvider(rideId))
      ..invalidate(rideProvider(rideId));
  }
}

final meetingPointActionsProvider = Provider<MeetingPointActions>(MeetingPointActions.new);

/// Arrêts restants et liens GPS (conducteur).
final navigationProvider = FutureProvider.autoDispose.family<NavigationPlan, String>(
  (ref, id) => ref.watch(ridesApiProvider).navigation(id),
  retry: (retryCount, error) => null,
);

final rideProvider = AsyncNotifierProvider.autoDispose.family<RideController, RideDetails, String>(
  RideController.new,
  retry: (retryCount, error) => null,
);

/// Suggestions de passagers pour le conducteur ; inviter retire la personne de la liste.
class SuggestionsController extends AsyncNotifier<Suggestions> {
  SuggestionsController(this.id);

  final String id;

  @override
  Future<Suggestions> build() => ref.watch(ridesApiProvider).suggestions(id);

  Future<void> invite(String userId) async {
    final proposal = await ref.read(ridesApiProvider).invite(id, userId);
    // Écran quitté pendant la requête : l'invitation est partie, rien d'autre à faire ici.
    if (!ref.mounted) return;
    // La proposition du conducteur montre maintenant ce passager.
    ref.read(weekProposalsProvider(isoWeekOf(proposal.day)).notifier).replace(proposal);
    ref.invalidateSelf();
  }
}

final suggestionsProvider = AsyncNotifierProvider.autoDispose
    .family<SuggestionsController, Suggestions, String>(
      SuggestionsController.new,
      retry: (retryCount, error) => null,
    );
