import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/core/api/api_client.dart';
import 'package:unimoov/core/api/auth_interceptor.dart';
import 'package:unimoov/core/storage/token_storage.dart';
import 'package:unimoov/features/auth/domain/auth_tokens.dart';

/// Serveur factice : accepte seulement le jeton d'accès courant.
class TokenCheckingAdapter implements HttpClientAdapter {
  String validToken = 'access-1';
  final List<String?> seenAuthorization = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? _,
  ) async {
    final auth = options.headers['Authorization'] as String?;
    seenAuthorization.add(auth);
    final ok = auth == 'Bearer $validToken';
    return ResponseBody.fromString(
      jsonEncode(
        ok
            ? {'ok': true}
            : {
                'error': {'code': 'unauthorized', 'message': ''},
              },
      ),
      ok ? 200 : 401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late TokenCheckingAdapter server;
  late MemoryTokenStorage storage;
  late int refreshCalls;
  late int expiredCalls;
  late Future<AuthTokens> Function(String) refreshImpl;

  Dio buildDio() {
    final plain = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = server;
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = server;
    dio.interceptors.add(
      AuthInterceptor(
        storage: storage,
        refresh: (token) {
          refreshCalls++;
          return refreshImpl(token);
        },
        retry: plain.fetch,
        onSessionExpired: () => expiredCalls++,
      ),
    );
    return dio;
  }

  setUp(() {
    server = TokenCheckingAdapter();
    storage = MemoryTokenStorage()
      ..tokens = const AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1');
    refreshCalls = 0;
    expiredCalls = 0;
    refreshImpl = (token) async {
      server.validToken = 'access-2';
      return const AuthTokens(accessToken: 'access-2', refreshToken: 'refresh-2');
    };
  });

  test('ajoute le JWT aux routes protégées, pas aux routes d’auth', () async {
    final dio = buildDio();
    await dio.get<void>('/api/v1/me');
    expect(server.seenAuthorization.last, 'Bearer access-1');
    await expectLater(dio.post<void>('/api/v1/auth/login'), throwsA(isA<DioException>()));
    expect(server.seenAuthorization.last, isNull);
  });

  test('sur 401 : rafraîchit, enregistre les nouveaux jetons et rejoue', () async {
    server.validToken = 'expired';
    refreshImpl = (_) async {
      server.validToken = 'access-2';
      return const AuthTokens(accessToken: 'access-2', refreshToken: 'refresh-2');
    };
    final response = await buildDio().get<Map<String, dynamic>>('/api/v1/me');
    expect(response.statusCode, 200);
    expect(refreshCalls, 1);
    expect(storage.tokens!.refreshToken, 'refresh-2');
  });

  test('requêtes simultanées : un seul refresh (pas de réutilisation du jeton)', () async {
    server.validToken = 'expired';
    final dio = buildDio();
    final results = await Future.wait([
      dio.get<void>('/api/v1/me'),
      dio.get<void>('/api/v1/me/pauses'),
      dio.get<void>('/api/v1/me'),
    ]);
    expect(results.every((r) => r.statusCode == 200), isTrue);
    expect(refreshCalls, 1);
  });

  test('refresh refusé (401) : session effacée et signalée', () async {
    server.validToken = 'expired';
    refreshImpl = (_) async =>
        throw const ApiException('invalid_refresh_token', '', statusCode: 401);
    await expectLater(buildDio().get<void>('/api/v1/me'), throwsA(isA<DioException>()));
    expect(storage.tokens, isNull);
    expect(expiredCalls, 1);
  });

  test('refresh impossible (réseau) : la session est conservée', () async {
    server.validToken = 'expired';
    refreshImpl = (_) async => throw const ApiException('network_error', '');
    await expectLater(buildDio().get<void>('/api/v1/me'), throwsA(isA<DioException>()));
    expect(storage.tokens, isNotNull);
    expect(expiredCalls, 0);
  });

  test('sans jetons : pas de refresh, session signalée perdue', () async {
    storage.tokens = null;
    await expectLater(buildDio().get<void>('/api/v1/me'), throwsA(isA<DioException>()));
    expect(refreshCalls, 0);
    expect(expiredCalls, 1);
  });
}
