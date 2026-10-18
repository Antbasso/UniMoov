import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/authenticated_dio.dart';
import '../../demo/demo_mode.dart';
import '../domain/achievements.dart';

abstract interface class AchievementsApi {
  Future<Achievements> achievements();
  Future<Leaderboard> leaderboard();
}

class DioAchievementsApi implements AchievementsApi {
  const DioAchievementsApi(this._dio);

  final Dio _dio;

  @override
  Future<Achievements> achievements() => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/me/achievements');
    return Achievements.fromJson(response.data!);
  });

  @override
  Future<Leaderboard> leaderboard() => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/leaderboard');
    return Leaderboard.fromJson(response.data!);
  });
}

final achievementsApiProvider = Provider<AchievementsApi>(
  (ref) => ref.watch(demoProvider) ?? DioAchievementsApi(ref.watch(dioProvider)),
);
