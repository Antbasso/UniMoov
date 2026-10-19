import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/authenticated_dio.dart';
import '../../proposals/domain/proposal.dart';
import '../domain/ride.dart';
import '../../demo/demo_mode.dart';

abstract interface class RidesApi {
  Future<RideDetails> ride(String id);

  /// Avant confirmation : tracé approximatif du trajet proposé.
  Future<RidePreview> preview(String id);

  /// `null` : revenir à son adresse. Passager, avant ou après avoir accepté.
  Future<void> setMeetingPoint(String id, MeetingPoint? point);

  /// Conducteur : proposer un point de rencontre à un passager.
  Future<void> proposeMeetingPoint(String id, String userId, MeetingPoint point);

  /// Passager : accepter ou refuser le point proposé par le conducteur.
  Future<void> answerMeetingPoint(String id, {required bool accept});

  /// Parkings publics et aires de covoiturage de la zone (vide si le service ne répond pas).
  Future<List<MeetingSpot>> meetingSpots(MapBounds bounds);
  Future<Suggestions> suggestions(String id);
  Future<Proposal> invite(String id, String userId);

  /// Conducteur : départ, « monté », arrêts et liens GPS.
  Future<void> start(String id);
  Future<void> pickedUp(String id, String userId);
  Future<NavigationPlan> navigation(String id);

  /// Passager : présence validée par proximité ; renvoie `true` si le paiement est passé.
  Future<void> presence(String id);
  Future<void> finish(String id);

  /// Trajets terminés, du plus récent au plus ancien.
  Future<List<HistoryEntry>> history();
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
  Future<RidePreview> preview(String id) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/rides/$id/preview');
    return RidePreview.fromJson(response.data!);
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
  Future<void> proposeMeetingPoint(String id, String userId, MeetingPoint point) => guardApi(
    () => _dio.put<void>(
      '/api/v1/rides/$id/participants/$userId/pickup-proposal',
      data: {'label': point.label, 'lat': point.lat, 'lon': point.lon},
    ),
  );

  @override
  Future<void> answerMeetingPoint(String id, {required bool accept}) => guardApi(
    () => _dio.post<void>('/api/v1/rides/$id/me/pickup-proposal', data: {'accept': accept}),
  );

  @override
  Future<List<MeetingSpot>> meetingSpots(MapBounds bounds) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/places/meeting-spots',
      queryParameters: {
        'south': bounds.south,
        'west': bounds.west,
        'north': bounds.north,
        'east': bounds.east,
      },
    );
    return [
      for (final s in response.data!['spots'] as List<dynamic>)
        MeetingSpot.fromJson(s as Map<String, dynamic>),
    ];
  });

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

  @override
  Future<void> start(String id) => guardApi(() => _dio.post<void>('/api/v1/rides/$id/start'));

  @override
  Future<void> pickedUp(String id, String userId) =>
      guardApi(() => _dio.post<void>('/api/v1/rides/$id/participants/$userId/picked-up'));

  @override
  Future<NavigationPlan> navigation(String id) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/rides/$id/navigation');
    return NavigationPlan.fromJson(response.data!);
  });

  @override
  Future<void> presence(String id) =>
      guardApi(() => _dio.post<Map<String, dynamic>>('/api/v1/rides/$id/presence'));

  @override
  Future<void> finish(String id) => guardApi(() => _dio.post<void>('/api/v1/rides/$id/finish'));

  @override
  Future<List<HistoryEntry>> history() => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/rides/history');
    return [
      for (final r in response.data!['rides'] as List<dynamic>)
        HistoryEntry.fromJson(r as Map<String, dynamic>),
    ];
  });
}

final ridesApiProvider = Provider<RidesApi>(
  (ref) => ref.watch(demoProvider) ?? DioRidesApi(ref.watch(dioProvider)),
);
