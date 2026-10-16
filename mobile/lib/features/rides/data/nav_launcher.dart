import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/ride.dart';

/// Ouverture des applications GPS (deep links, cahier §15), derrière une interface testable.
abstract interface class NavLauncher {
  /// Applications installées sur le téléphone, dans l'ordre de présentation.
  Future<List<NavApp>> installed();
  Future<bool> open(Uri link);
}

class UrlNavLauncher implements NavLauncher {
  const UrlNavLauncher();

  /// Schémas déclarés dans Info.plist (`LSApplicationQueriesSchemes`) et AndroidManifest.
  static Uri? _probe(NavApp app) => switch (app) {
    // Le lien https s'ouvre toujours (application ou navigateur).
    NavApp.googleMaps => null,
    NavApp.waze => Uri.parse('waze://'),
    NavApp.appleMaps => defaultTargetPlatform == TargetPlatform.iOS ? Uri.parse('maps://') : null,
  };

  @override
  Future<List<NavApp>> installed() async {
    final apps = <NavApp>[];
    for (final app in NavApp.values) {
      final probe = _probe(app);
      if (app == NavApp.appleMaps && probe == null) continue;
      if (probe == null || await canLaunchUrl(probe)) apps.add(app);
    }
    return apps;
  }

  @override
  Future<bool> open(Uri link) => launchUrl(link, mode: LaunchMode.externalApplication);
}

final navLauncherProvider = Provider<NavLauncher>((ref) => const UrlNavLauncher());
