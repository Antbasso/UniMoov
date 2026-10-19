import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/storage/token_storage.dart';
import 'data/demo_backend.dart';

/// Mode démo : l'app tourne sur un serveur fictif intégré (données inventées, aucun réseau).
/// `null` hors démo. Les API, le suivi en direct et le stockage des jetons basculent dessus.
class DemoMode extends Notifier<DemoBackend?> {
  /// Jetons de la session de démo, en mémoire seulement (jamais dans le trousseau).
  final storage = MemoryTokenStorage();
  DemoBackend? _backend;

  @override
  DemoBackend? build() {
    // Minuteries de la simulation arrêtées avec l'app.
    ref.onDispose(() => _backend?.dispose());
    return null;
  }

  /// `withAccount` : compte prêt à l'emploi ; sinon parcours d'inscription complet.
  DemoBackend start({bool withAccount = true}) {
    _backend?.dispose();
    storage.tokens = null;
    final backend = DemoBackend(clock: ref.read(clockProvider), withAccount: withAccount);
    _backend = backend;
    return state = backend;
  }

  void stop() {
    if (_backend == null) return;
    _backend?.dispose();
    _backend = null;
    storage.tokens = null;
    state = null;
  }
}

final demoProvider = NotifierProvider<DemoMode, DemoBackend?>(DemoMode.new);

/// Vrai pendant la démo (bandeau, aide à l'inscription).
final demoActiveProvider = Provider<bool>((ref) => ref.watch(demoProvider) != null);
