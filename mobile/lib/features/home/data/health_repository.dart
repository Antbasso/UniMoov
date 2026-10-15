import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/api_health.dart';

class HealthRepository {
  const HealthRepository(this._dio);

  final Dio _dio;

  Future<ApiHealth> fetch() async {
    try {
      final response = await _dio.get<Object?>(
        '/health',
        options: Options(validateStatus: (status) => status == 200 || status == 503),
      );
      return parseHealth(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

final healthRepositoryProvider = Provider((ref) => HealthRepository(ref.watch(dioProvider)));
