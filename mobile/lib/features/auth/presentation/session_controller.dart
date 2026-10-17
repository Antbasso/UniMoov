import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/token_storage.dart';
import '../data/auth_api.dart';
import '../../notifications/data/notifications_api.dart';
import '../../notifications/data/push_service.dart';
import '../../notifications/presentation/push_controller.dart';
import '../domain/auth_tokens.dart';

enum SessionStatus { signedOut, signedIn }

/// Session de l'utilisateur : restaurée au lancement depuis le stockage sécurisé.
class SessionController extends AsyncNotifier<SessionStatus> {
  TokenStorage get _storage => ref.read(tokenStorageProvider);

  @override
  Future<SessionStatus> build() async => await ref.watch(tokenStorageProvider).read() == null
      ? SessionStatus.signedOut
      : SessionStatus.signedIn;

  Future<void> signIn(AuthTokens tokens) async {
    await _storage.write(tokens);
    state = const AsyncData(SessionStatus.signedIn);
  }

  /// Déconnexion volontaire : révoque la session côté serveur si possible.
  Future<void> signOut() async {
    // Tant que la session est valide : l'appareil ne recevra plus les notifications du compte.
    // Jeton relu auprès de Firebase s'il n'a pas pu être enregistré pendant la session.
    final store = ref.read(deviceTokenStoreProvider);
    store.token ??= await ref.read(pushServiceProvider).currentToken();
    await store.unregister(ref.read(notificationsApiProvider));
    final tokens = await _storage.read();
    await _storage.clear();
    state = const AsyncData(SessionStatus.signedOut);
    if (tokens != null) {
      try {
        await ref.read(authApiProvider).logout(tokens.refreshToken);
      } on Object {
        // Hors ligne : les jetons locaux sont déjà effacés, le refresh expirera seul.
      }
    }
  }

  /// Compte supprimé : le serveur a déjà retiré sessions et appareils ; seul le local reste.
  Future<void> accountDeleted() async {
    ref.read(deviceTokenStoreProvider).token = null;
    await _storage.clear();
    state = const AsyncData(SessionStatus.signedOut);
  }

  /// Session perdue (refresh refusé) : retour à l'accueil.
  void expire() => state = const AsyncData(SessionStatus.signedOut);
}

final sessionProvider = AsyncNotifierProvider<SessionController, SessionStatus>(
  SessionController.new,
  retry: (retryCount, error) => null,
);
