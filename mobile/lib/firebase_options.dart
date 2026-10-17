import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Configuration Firebase du projet `unimoov-383ff` (identifiants publics de l'app, pas des
/// secrets). Équivalent de ce que génère `flutterfire configure`.
///
/// La clé d'API vient de `google-services.json` (Android) et `GoogleService-Info.plist` (iOS) ;
/// tant qu'elle manque, `currentPlatform` vaut `null` et les notifications push sont
/// désactivées sans erreur (le reste de l'app fonctionne).
abstract final class DefaultFirebaseOptions {
  static const _projectId = 'unimoov-383ff';
  static const _senderId = '1069216685907';

  /// À remplir avec `current_key` de google-services.json.
  static const String? _androidApiKey = null;

  /// À remplir avec `API_KEY` de GoogleService-Info.plist.
  static const String? _iosApiKey = null;

  static FirebaseOptions? get currentPlatform => switch (defaultTargetPlatform) {
    TargetPlatform.android when _androidApiKey != null => FirebaseOptions(
      apiKey: _androidApiKey!,
      appId: '1:1069216685907:android:0d1f0de8fd93208abb0ba6',
      messagingSenderId: _senderId,
      projectId: _projectId,
    ),
    TargetPlatform.iOS when _iosApiKey != null => FirebaseOptions(
      apiKey: _iosApiKey!,
      appId: '1:1069216685907:ios:b5384ee400cdaafbbb0ba6',
      messagingSenderId: _senderId,
      projectId: _projectId,
      iosBundleId: 'fr.unimoov.unimoov',
    ),
    _ => null,
  };
}
