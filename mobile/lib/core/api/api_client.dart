import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// URL de l'API, fixée à la compilation : `--dart-define=API_BASE_URL=https://…`.
/// Par défaut, l'hôte de la machine vu depuis l'émulateur Android.
const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000');

/// Erreur d'API au format `{ "error": { "code", "message" } }` (docs/api.md).
class ApiException implements Exception {
  const ApiException(this.code, this.message, {this.statusCode});

  final String code;
  final String message;
  final int? statusCode;

  /// Convertit une erreur dio en erreur métier, sans jamais exposer le corps brut.
  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    final data = response?.data;
    if (data is Map<String, dynamic> && data['error'] is Map<String, dynamic>) {
      final body = data['error'] as Map<String, dynamic>;
      return ApiException(
        body['code'] as String? ?? 'unknown',
        body['message'] as String? ?? '',
        statusCode: response?.statusCode,
      );
    }
    if (response == null) return const ApiException('network_error', 'Serveur injoignable');
    return ApiException('http_${response.statusCode}', '', statusCode: response.statusCode);
  }

  @override
  String toString() => 'ApiException($code, $statusCode)';
}

Dio createDio({String baseUrl = apiBaseUrl}) => Dio(
  BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
    responseType: ResponseType.json,
  ),
);

/// Exécute un appel et convertit les erreurs dio en [ApiException].
Future<T> guardApi<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (error) {
    throw ApiException.fromDio(error);
  }
}

/// Client sans jeton : routes d'authentification et rejeu des requêtes.
final publicDioProvider = Provider<Dio>((ref) => createDio());
