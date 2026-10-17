import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/authenticated_dio.dart';
import '../domain/trust.dart';
import '../../demo/demo_mode.dart';

abstract interface class TrustApi {
  /// Palier de pénalité si j'annule maintenant (annulation après acceptation).
  Future<CancellationInfo> cancellation(String rideId);
  Future<CancelTier> cancel(String rideId);

  Future<RideRatings> ratings(String rideId);
  Future<void> rate(String rideId, String userId, int stars);

  Future<Reliability> reliability();

  Future<List<Dispute>> disputes(String rideId);
  Future<Dispute> openDispute(String rideId, DisputeReason reason, String? message);
  Future<Dispute> escalate(String disputeId, String? message);

  Future<void> report(String userId, ReportReason reason, String? message);
}

class DioTrustApi implements TrustApi {
  const DioTrustApi(this._dio);

  final Dio _dio;

  @override
  Future<CancellationInfo> cancellation(String rideId) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/rides/$rideId/cancellation');
    return CancellationInfo.fromJson(response.data!);
  });

  @override
  Future<CancelTier> cancel(String rideId) => guardApi(() async {
    final response = await _dio.post<Map<String, dynamic>>('/api/v1/rides/$rideId/cancel');
    return CancelTier.values.byName(response.data!['tier'] as String);
  });

  @override
  Future<RideRatings> ratings(String rideId) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/rides/$rideId/ratings');
    return RideRatings.fromJson(response.data!);
  });

  @override
  Future<void> rate(String rideId, String userId, int stars) => guardApi(
    () => _dio.post<void>(
      '/api/v1/rides/$rideId/ratings',
      data: {'ratedUserId': userId, 'stars': stars},
    ),
  );

  @override
  Future<Reliability> reliability() => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/me/reliability');
    return Reliability.fromJson(response.data!);
  });

  @override
  Future<List<Dispute>> disputes(String rideId) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/rides/$rideId/disputes');
    return [
      for (final d in response.data!['disputes'] as List<dynamic>)
        Dispute.fromJson(d as Map<String, dynamic>),
    ];
  });

  @override
  Future<Dispute> openDispute(String rideId, DisputeReason reason, String? message) =>
      guardApi(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/v1/rides/$rideId/disputes',
          data: {'reason': reason.wire, 'message': ?message},
        );
        return Dispute.fromJson(response.data!);
      });

  @override
  Future<Dispute> escalate(String disputeId, String? message) => guardApi(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/disputes/$disputeId/escalate',
      data: {'message': ?message},
    );
    return Dispute.fromJson(response.data!);
  });

  @override
  Future<void> report(String userId, ReportReason reason, String? message) => guardApi(
    () => _dio.post<void>(
      '/api/v1/reports',
      data: {'targetUserId': userId, 'reason': reason.wire, 'message': ?message},
    ),
  );
}

final trustApiProvider = Provider<TrustApi>(
  (ref) => ref.watch(demoProvider) ?? DioTrustApi(ref.watch(dioProvider)),
);
