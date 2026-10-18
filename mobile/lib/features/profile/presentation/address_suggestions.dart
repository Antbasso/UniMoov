import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profile_api.dart';

/// Adresses proposées pendant la saisie : une requête après une courte pause de frappe, et
/// seulement la réponse à la dernière saisie est gardée. `null` : rien à proposer.
class AddressSuggestionsController extends Notifier<AsyncValue<List<String>>?> {
  static const debounce = Duration(milliseconds: 350);
  static const minLength = 3;

  Timer? _timer;
  int _generation = 0;

  @override
  AsyncValue<List<String>>? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void search(String text) {
    _timer?.cancel();
    final query = text.trim();
    final generation = ++_generation;
    if (query.length < minLength) {
      state = null;
      return;
    }
    _timer = Timer(debounce, () async {
      state = const AsyncLoading();
      final result = await AsyncValue.guard(
        () => ref.read(profileApiProvider).suggestAddresses(query),
      );
      if (ref.mounted && generation == _generation) state = result;
    });
  }

  /// Adresse choisie : la liste se ferme.
  void clear() {
    _timer?.cancel();
    _generation++;
    state = null;
  }
}

final addressSuggestionsProvider =
    NotifierProvider.autoDispose<AddressSuggestionsController, AsyncValue<List<String>>?>(
      AddressSuggestionsController.new,
    );
