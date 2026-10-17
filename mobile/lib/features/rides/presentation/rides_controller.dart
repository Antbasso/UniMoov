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
