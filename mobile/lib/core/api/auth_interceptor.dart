import 'package:dio/dio.dart';

import '../../features/auth/domain/auth_tokens.dart';
import '../storage/token_storage.dart';
import 'api_client.dart';

/// Ajoute le JWT d'accès et, sur un 401, rafraîchit la session une seule fois puis rejoue.
///
/// Les erreurs sont traitées une à une (QueuedInterceptor) : si plusieurs requêtes échouent
/// en même temps, seule la première rafraîchit ; les suivantes voient que le jeton a changé
/// et rejouent directement. Indispensable : le serveur révoque la session si un refresh token
/// déjà utilisé lui est présenté.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.storage,
    required this.refresh,
    required this.retry,
    required this.onSessionExpired,
  });

  final TokenStorage storage;

  /// Échange le refresh token ; lève [ApiException] (401 : session perdue).
  final Future<AuthTokens> Function(String refreshToken) refresh;

  /// Rejoue une requête (client sans cet intercepteur).
  final Future<Response<dynamic>> Function(RequestOptions options) retry;
  final void Function() onSessionExpired;

  static const _retriedKey = 'auth.retried';
  static bool _isAuthRoute(RequestOptions options) => options.path.contains('/auth/');

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_isAuthRoute(options)) {
      final tokens = await storage.read();
      if (tokens != null) options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        _isAuthRoute(options) ||
        options.extra[_retriedKey] == true) {
      return handler.next(err);
    }

    final current = await storage.read();
    if (current == null) {
      onSessionExpired();
      return handler.next(err);
    }

    var tokens = current;
    final usedHeader = options.headers['Authorization'];
    // Le jeton n'a pas changé depuis l'envoi : c'est à nous de rafraîchir.
    if (usedHeader == 'Bearer ${current.accessToken}') {
      try {
        tokens = await refresh(current.refreshToken);
      } on ApiException catch (refreshError) {
        // Refus du serveur : session révoquée ou expirée. Autre cas (réseau) : on garde la
        // session et l'erreur remonte, l'utilisateur pourra réessayer.
        if (refreshError.statusCode == 401) {
          await storage.clear();
          onSessionExpired();
        }
        return handler.next(err);
      } on Object {
        return handler.next(err);
      }
      await storage.write(tokens);
    }

    options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    options.extra[_retriedKey] = true;
    try {
      handler.resolve(await retry(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}
