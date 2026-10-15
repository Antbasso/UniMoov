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
    final api = ref.read(ridesApiProvider);
    await api.setMeetingPoint(id, point);
    final updated = await api.ride(id);
    if (ref.mounted) state = AsyncData(updated);
  }
}

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
    final api = ref.read(ridesApiProvider);
    final proposal = await api.invite(id, userId);
    // La proposition du conducteur montre maintenant ce passager.
    ref.read(weekProposalsProvider(isoWeekOf(proposal.day)).notifier).replace(proposal);
    final refreshed = await api.suggestions(id);
    if (ref.mounted) state = AsyncData(refreshed);
  }
}

final suggestionsProvider = AsyncNotifierProvider.autoDispose
    .family<SuggestionsController, Suggestions, String>(
      SuggestionsController.new,
      retry: (retryCount, error) => null,
    );
