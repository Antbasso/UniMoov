import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_api.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../storage/token_storage.dart';
import 'api_client.dart';
import 'auth_interceptor.dart';

/// Client des routes protégées : JWT ajouté et session rafraîchie automatiquement.
final dioProvider = Provider<Dio>((ref) {
  final publicDio = ref.watch(publicDioProvider);
  final authApi = ref.watch(authApiProvider);
  final dio = createDio(baseUrl: publicDio.options.baseUrl)
    ..httpClientAdapter = publicDio.httpClientAdapter;
  dio.interceptors.add(
    AuthInterceptor(
      storage: ref.watch(tokenStorageProvider),
      refresh: authApi.refresh,
      retry: publicDio.fetch,
      onSessionExpired: () => ref.read(sessionProvider.notifier).expire(),
    ),
  );
  return dio;
});
