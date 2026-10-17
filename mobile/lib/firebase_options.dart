import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Configuration Firebase du projet `unimoov-383ff` (identifiants publics de l'app, pas des
/// secrets). Équivalent de ce que génère `flutterfire configure`.
///
/// Les clés d'API viennent de `google-services.json` (Android) et `GoogleService-Info.plist`
/// (iOS). Elles identifient l'app auprès de Firebase et sont faites pour être embarquées ; elles
/// se restreignent dans Google Cloud (paquet Android, identifiant iOS). Hors Android et
/// iOS, `currentPlatform` vaut `null` et le push est désactivé sans erreur.
abstract final class DefaultFirebaseOptions {
  static const _projectId = 'unimoov-383ff';
  static const _senderId = '1069216685907';

  /// `current_key` de google-services.json.
  static const _androidApiKey = 'AIzaSyCHR36tZs5ZfXS_vT6jdX9m6GuFsA_4wHs';

  /// `API_KEY` de GoogleService-Info.plist.
  static const _iosApiKey = 'AIzaSyAn1k2cHT8Q8erqJLBaSMn6b94q3P1c5Bg';

  static FirebaseOptions? get currentPlatform => switch (defaultTargetPlatform) {
    TargetPlatform.android => const FirebaseOptions(
      apiKey: _androidApiKey,
      appId: '1:1069216685907:android:0d1f0de8fd93208abb0ba6',
      messagingSenderId: _senderId,
      projectId: _projectId,
    ),
    TargetPlatform.iOS => const FirebaseOptions(
      apiKey: _iosApiKey,
      appId: '1:1069216685907:ios:b5384ee400cdaafbbb0ba6',
      messagingSenderId: _senderId,
      projectId: _projectId,
      iosBundleId: 'fr.unimoov.unimoov',
    ),
    _ => null,
  };
}
