import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/core/api/api_client.dart';
import 'package:unimoov/features/home/data/health_repository.dart';
import 'package:unimoov/features/home/domain/api_health.dart';

/// Adaptateur HTTP factice : répond un statut et un corps JSON, ou échoue.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter({this.status = 200, this.body, this.fail = false});

  final int status;
  final Object? body;
  final bool fail;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancel,
  ) async {
    lastRequest = options;
    if (fail) throw DioException.connectionError(requestOptions: options, reason: 'refused');
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

HealthRepository repoWith(FakeAdapter adapter) =>
    HealthRepository(createDio(baseUrl: 'http://api.test')..httpClientAdapter = adapter);

void main() {
  group('parseHealth', () {
    test('ok et dégradé', () {
      expect(parseHealth({'status': 'ok', 'db': 'ok'}), ApiHealth.ok);
      expect(parseHealth({'status': 'degraded', 'db': 'down'}), ApiHealth.degraded);
    });

    test('refuse une réponse inattendue', () {
      expect(() => parseHealth('ok'), throwsFormatException);
      expect(() => parseHealth({'status': 'up'}), throwsFormatException);
    });
  });

  group('HealthRepository', () {
    test('200 → ok, sur /health', () async {
      final adapter = FakeAdapter(body: {'status': 'ok', 'db': 'ok'});
      expect(await repoWith(adapter).fetch(), ApiHealth.ok);
      expect(adapter.lastRequest!.uri.toString(), 'http://api.test/health');
    });

    test('503 → dégradé (pas une erreur)', () async {
      final adapter = FakeAdapter(status: 503, body: {'status': 'degraded', 'db': 'down'});
      expect(await repoWith(adapter).fetch(), ApiHealth.degraded);
    });

    test('réseau coupé → ApiException network_error', () async {
      await expectLater(
        repoWith(FakeAdapter(fail: true)).fetch(),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'network_error')),
      );
    });

    test('erreur au format de l’API → code et message', () async {
      final adapter = FakeAdapter(
        status: 500,
        body: {
          'error': {'code': 'internal_error', 'message': 'Erreur interne'},
        },
      );
      await expectLater(
        repoWith(adapter).fetch(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'internal_error')
              .having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });
  });
}
