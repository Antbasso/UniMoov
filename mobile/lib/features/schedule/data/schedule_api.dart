import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/authenticated_dio.dart';
import '../domain/schedule.dart';
import '../../demo/demo_mode.dart';

/// Routes « Agenda » (docs/api.md).
abstract interface class ScheduleApi {
  Future<CalendarConnection?> getConnection();
  Future<CalendarConnection> connectIcs(String url);
  Future<CalendarConnection> sync();
  Future<void> disconnect(String id);
  Future<List<ManualDay>> getManual();
  Future<List<ManualDay>> setManual(List<ManualDay> days);
}

class DioScheduleApi implements ScheduleApi {
  const DioScheduleApi(this._dio);

  final Dio _dio;

  @override
  Future<CalendarConnection?> getConnection() => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/calendar/connections');
    final json = response.data!['connection'] as Map<String, dynamic>?;
    return json == null ? null : CalendarConnection.fromJson(json);
  });

  @override
  Future<CalendarConnection> connectIcs(String url) => guardApi(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/calendar/connections',
      data: {'provider': 'ics', 'url': url, 'consent': true},
    );
    return CalendarConnection.fromJson(response.data!['connection'] as Map<String, dynamic>);
  });

  @override
  Future<CalendarConnection> sync() => guardApi(() async {
    final response = await _dio.post<Map<String, dynamic>>('/api/v1/calendar/sync');
    return CalendarConnection.fromJson(response.data!['connection'] as Map<String, dynamic>);
  });

  @override
  Future<void> disconnect(String id) =>
      guardApi(() => _dio.delete<void>('/api/v1/calendar/connections/$id'));

  List<ManualDay> _days(Map<String, dynamic> json) => [
    for (final d in json['days'] as List<dynamic>) ManualDay.fromJson(d as Map<String, dynamic>),
  ];

  @override
  Future<List<ManualDay>> getManual() => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/schedule/manual');
    return _days(response.data!);
  });

  @override
  Future<List<ManualDay>> setManual(List<ManualDay> days) => guardApi(() async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/v1/schedule/manual',
      data: {'days': days.map((d) => d.toJson()).toList()},
    );
    return _days(response.data!);
  });
}

final scheduleApiProvider = Provider<ScheduleApi>(
  (ref) => ref.watch(demoProvider) ?? DioScheduleApi(ref.watch(dioProvider)),
);
