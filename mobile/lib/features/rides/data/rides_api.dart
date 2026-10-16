import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/authenticated_dio.dart';
import '../../proposals/domain/proposal.dart';
import '../domain/ride.dart';

abstract interface class RidesApi {
  Future<RideDetails> ride(String id);

  /// `null` : revenir à son adresse.
  Future<void> setMeetingPoint(String id, MeetingPoint? point);
  Future<Suggestions> suggestions(String id);
  Future<Proposal> invite(String id, String userId);
}

class DioRidesApi implements RidesApi {
  const DioRidesApi(this._dio);

  final Dio _dio;

  @override
  Future<RideDetails> ride(String id) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/rides/$id');
    return RideDetails.fromJson(response.data!);
  });

  @override
  Future<void> setMeetingPoint(String id, MeetingPoint? point) => guardApi(
    () => _dio.put<void>(
      '/api/v1/rides/$id/me/pickup',
      data: point == null
          ? {'useMeetingPoint': false}
          : {'useMeetingPoint': true, 'label': point.label, 'lat': point.lat, 'lon': point.lon},
    ),
  );

  @override
  Future<Suggestions> suggestions(String id) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/rides/$id/suggestions');
    return Suggestions.fromJson(response.data!);
  });

  @override
  Future<Proposal> invite(String id, String userId) => guardApi(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/rides/$id/suggestions/$userId/invite',
    );
    return Proposal.fromJson(response.data!);
  });
}

final ridesApiProvider = Provider<RidesApi>((ref) => DioRidesApi(ref.watch(dioProvider)));
