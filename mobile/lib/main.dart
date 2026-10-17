import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'features/rides/presentation/ride_map.dart';

void main() {
  // Version publiée : jamais de HTTP en clair vers l'API ni le fond de carte (jetons, positions).
  if (kReleaseMode) assertSecureEndpoints(apiBaseUrl: apiBaseUrl, pmtilesUrl: pmtilesUrl);
  // Erreurs non rattrapées : affichées en débogage, jamais avec des données (pas de service de
  // rapport d'erreurs dans le pilote).
  FlutterError.onError = FlutterError.presentError;
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Erreur non rattrapée : ${error.runtimeType}');
    return true;
  };
  runApp(const ProviderScope(child: UniMoovApp()));
}
