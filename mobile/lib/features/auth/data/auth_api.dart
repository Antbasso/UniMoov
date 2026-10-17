import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/auth_tokens.dart';
import '../../demo/demo_mode.dart';

/// Routes d'authentification (docs/api.md, « Auth »), sans JWT.
abstract interface class AuthApi {
  Future<void> requestCode(String universityEmail);
  Future<AuthTokens> verify({
    required String universityEmail,
    required String code,
    required String firstName,
    required String lastName,
    required String password,
  });
  Future<AuthTokens> login({required String universityEmail, required String password});
  Future<AuthTokens> refresh(String refreshToken);
  Future<void> logout(String refreshToken);
}

class DioAuthApi implements AuthApi {
  const DioAuthApi(this._dio);

  final Dio _dio;
  static const _base = '/api/v1/auth';

  Future<AuthTokens> _tokens(String path, Map<String, Object?> body) => guardApi(() async {
    final response = await _dio.post<Map<String, dynamic>>('$_base$path', data: body);
    return AuthTokens.fromJson(response.data!);
  });

  @override
  Future<void> requestCode(String universityEmail) => guardApi(
    () => _dio.post<void>('$_base/signup/request-code', data: {'universityEmail': universityEmail}),
  );

  @override
  Future<AuthTokens> verify({
    required String universityEmail,
    required String code,
    required String firstName,
    required String lastName,
    required String password,
  }) => _tokens('/signup/verify', {
    'universityEmail': universityEmail,
    'code': code,
    'firstName': firstName,
    'lastName': lastName,
    'password': password,
  });

  @override
  Future<AuthTokens> login({required String universityEmail, required String password}) =>
      _tokens('/login', {'universityEmail': universityEmail, 'password': password});

  @override
  Future<AuthTokens> refresh(String refreshToken) =>
      _tokens('/refresh', {'refreshToken': refreshToken});

  @override
  Future<void> logout(String refreshToken) =>
      guardApi(() => _dio.post<void>('$_base/logout', data: {'refreshToken': refreshToken}));
}

final authApiProvider = Provider<AuthApi>(
  (ref) => ref.watch(demoProvider) ?? DioAuthApi(ref.watch(publicDioProvider)),
);
