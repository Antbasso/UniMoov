import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/domain/auth_tokens.dart';

/// Stockage des jetons de session ; jamais en clair hors du trousseau du système.
abstract interface class TokenStorage {
  Future<AuthTokens?> read();
  Future<void> write(AuthTokens tokens);
  Future<void> clear();
}

/// Keychain iOS / Keystore Android via flutter_secure_storage. Les deux jetons sont écrits
/// ensemble (une seule clé) : une application tuée entre deux écritures ne laisse jamais un
/// jeton de rafraîchissement déjà échangé, que le serveur prendrait pour un vol.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // iOS : lisible après le premier déverrouillage, jamais copié vers un autre appareil.
            iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
          );

  final FlutterSecureStorage _storage;
  static const _sessionKey = 'auth.session';
  // Anciennes clés séparées : relues une fois, puis effacées.
  static const _accessKey = 'auth.accessToken';
  static const _refreshKey = 'auth.refreshToken';

  @override
  Future<AuthTokens?> read() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw != null) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        return AuthTokens(
          accessToken: json['accessToken'] as String,
          refreshToken: json['refreshToken'] as String,
        );
      } on Object {
        await clear();
        return null;
      }
    }
    final access = await _storage.read(key: _accessKey);
    final refresh = await _storage.read(key: _refreshKey);
    if (access == null || refresh == null) return null;
    final tokens = AuthTokens(accessToken: access, refreshToken: refresh);
    await write(tokens);
    return tokens;
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    await _storage.write(
      key: _sessionKey,
      value: jsonEncode({'accessToken': tokens.accessToken, 'refreshToken': tokens.refreshToken}),
    );
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _sessionKey);
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

/// Tests : stockage en mémoire, partageable entre deux lancements simulés de l'app.
class MemoryTokenStorage implements TokenStorage {
  AuthTokens? tokens;

  @override
  Future<AuthTokens?> read() async => tokens;

  @override
  Future<void> write(AuthTokens value) async => tokens = value;

  @override
  Future<void> clear() async => tokens = null;
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => SecureTokenStorage());
