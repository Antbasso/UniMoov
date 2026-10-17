import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/authenticated_dio.dart';
import '../domain/proposal.dart';

abstract interface class ProposalsApi {
  Future<List<Proposal>> week(String week);
  Future<Proposal> accept(String id);
  Future<void> decline(String id);

  /// Conducteur : réponse à une demande de place.
  Future<Proposal> answerRequest(String rideId, String userId, {required bool approve});
  Future<List<JoinableRide>> alternatives(String id);
  Future<List<JoinableRide>> search({
    required DateTime day,
    required Direction direction,
    String? time,
  });
}

class DioProposalsApi implements ProposalsApi {
  const DioProposalsApi(this._dio);

  final Dio _dio;

  List<JoinableRide> _rides(Map<String, dynamic> json) => [
    for (final r in json['rides'] as List<dynamic>)
      JoinableRide.fromJson(r as Map<String, dynamic>),
  ];

  @override
  Future<List<Proposal>> week(String week) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/proposals',
      queryParameters: {'week': week},
    );
    return [
      for (final p in response.data!['proposals'] as List<dynamic>)
        Proposal.fromJson(p as Map<String, dynamic>),
    ];
  });

  @override
  Future<Proposal> accept(String id) => guardApi(() async {
    final response = await _dio.post<Map<String, dynamic>>('/api/v1/proposals/$id/accept');
    return Proposal.fromJson(response.data!);
  });

  @override
  Future<Proposal> answerRequest(String rideId, String userId, {required bool approve}) =>
      guardApi(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/v1/rides/$rideId/requests/$userId/${approve ? 'approve' : 'reject'}',
        );
        return Proposal.fromJson(response.data!);
      });

  @override
  Future<void> decline(String id) =>
      guardApi(() => _dio.post<void>('/api/v1/proposals/$id/decline'));

  @override
  Future<List<JoinableRide>> alternatives(String id) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/proposals/$id/alternatives');
    return _rides(response.data!);
  });

  @override
  Future<List<JoinableRide>> search({
    required DateTime day,
    required Direction direction,
    String? time,
  }) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/search/rides',
      queryParameters: {
        'day':
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
        'direction': direction.wire,
        'time': ?time,
      },
    );
    return _rides(response.data!);
  });
}

final proposalsApiProvider = Provider<ProposalsApi>(
  (ref) => DioProposalsApi(ref.watch(dioProvider)),
);
