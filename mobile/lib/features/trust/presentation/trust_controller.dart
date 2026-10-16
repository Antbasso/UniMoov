import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/trust_api.dart';
import '../domain/trust.dart';

/// Mon score de fiabilité et ce qui l'explique.
final reliabilityProvider = FutureProvider.autoDispose<Reliability>(
  (ref) => ref.watch(trustApiProvider).reliability(),
  retry: (retryCount, error) => null,
);

/// Notes d'un trajet terminé : la note donnée s'affiche sans recharger.
class RatingsController extends AsyncNotifier<RideRatings> {
  RatingsController(this.rideId);

  final String rideId;

  @override
  Future<RideRatings> build() => ref.watch(trustApiProvider).ratings(rideId);

  Future<void> rate(String userId, int stars) async {
    await ref.read(trustApiProvider).rate(rideId, userId, stars);
    final current = state.value;
    if (!ref.mounted || current == null) return;
    state = AsyncData(
      RideRatings(
        open: current.open,
        people: [for (final p in current.people) p.userId == userId ? p.withStars(stars) : p],
      ),
    );
  }
}

final ratingsProvider = AsyncNotifierProvider.autoDispose
    .family<RatingsController, RideRatings, String>(
      RatingsController.new,
      retry: (retryCount, error) => null,
    );

/// Mes litiges sur un trajet ; ouvrir ou contester met la liste à jour.
class DisputesController extends AsyncNotifier<List<Dispute>> {
  DisputesController(this.rideId);

  final String rideId;

  @override
  Future<List<Dispute>> build() => ref.watch(trustApiProvider).disputes(rideId);

  Future<Dispute> open(DisputeReason reason, String? message) async {
    final dispute = await ref.read(trustApiProvider).openDispute(rideId, reason, message);
    _put(dispute);
    return dispute;
  }

  Future<void> escalate(String disputeId, String? message) async {
    _put(await ref.read(trustApiProvider).escalate(disputeId, message));
  }

  void _put(Dispute dispute) {
    if (!ref.mounted) return;
    final others = (state.value ?? const <Dispute>[]).where((d) => d.id != dispute.id);
    state = AsyncData([...others, dispute]);
    // Une correction change le score.
    ref.invalidate(reliabilityProvider);
  }
}

final disputesProvider = AsyncNotifierProvider.autoDispose
    .family<DisputesController, List<Dispute>, String>(
      DisputesController.new,
      retry: (retryCount, error) => null,
    );
