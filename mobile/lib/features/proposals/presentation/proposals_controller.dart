import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../data/proposals_api.dart';
import '../domain/proposal.dart';

/// Propositions d'une semaine ISO. Les actions renvoient l'état du serveur, qui fait foi.
class WeekProposalsController extends AsyncNotifier<List<Proposal>> {
  WeekProposalsController(this.week);

  final String week;

  ProposalsApi get _api => ref.read(proposalsApiProvider);

  @override
  Future<List<Proposal>> build() => ref.watch(proposalsApiProvider).week(week);

  Future<void> accept(String id) async {
    final updated = await _api.accept(id);
    state = AsyncData([for (final p in state.value ?? <Proposal>[]) p.id == id ? updated : p]);
  }

  Future<void> decline(String id) async {
    await _api.decline(id);
    state = AsyncData(await _api.week(week));
  }

  /// Monter dans une autre voiture (alternative ou recherche) : l'ancienne proposition
  /// du même créneau disparaît côté serveur.
  Future<void> join(String rideId) async {
    await _api.accept(rideId);
    state = AsyncData(await _api.week(week));
  }
}

final weekProposalsProvider =
    AsyncNotifierProvider.family<WeekProposalsController, List<Proposal>, String>(
      WeekProposalsController.new,
      retry: (retryCount, error) => null,
    );

final alternativesProvider = FutureProvider.autoDispose.family<List<JoinableRide>, String>(
  (ref, id) => ref.watch(proposalsApiProvider).alternatives(id),
  retry: (retryCount, error) => null,
);

class SearchState {
  const SearchState({this.results, this.busy = false, this.errorCode});

  final List<JoinableRide>? results;
  final bool busy;
  final String? errorCode;
}

/// Recherche manuelle (quota quotidien côté serveur).
class SearchController extends Notifier<SearchState> {
  @override
  SearchState build() => const SearchState();

  Future<void> search({required DateTime day, required Direction direction, String? time}) async {
    state = SearchState(results: state.results, busy: true);
    try {
      final results = await ref
          .read(proposalsApiProvider)
          .search(day: day, direction: direction, time: time);
      state = SearchState(results: results);
    } on ApiException catch (error) {
      state = SearchState(errorCode: error.code);
    }
  }
}

final searchProvider = NotifierProvider.autoDispose<SearchController, SearchState>(
  SearchController.new,
);
