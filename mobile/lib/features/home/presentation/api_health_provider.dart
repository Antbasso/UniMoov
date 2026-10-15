import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/health_repository.dart';
import '../domain/api_health.dart';

/// État de connexion à l'API affiché sur l'accueil (chargement, erreur, contenu).
/// Pas de réessai automatique : l'erreur s'affiche et l'utilisateur relance lui-même.
final apiHealthProvider = FutureProvider.autoDispose<ApiHealth>(
  (ref) => ref.watch(healthRepositoryProvider).fetch(),
  retry: (retryCount, error) => null,
);
