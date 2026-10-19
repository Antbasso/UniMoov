import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/authenticated_dio.dart';
import '../domain/me.dart';
import '../../demo/demo_mode.dart';

/// Routes du profil (docs/api.md, « Profil ») ; toutes exigent un JWT.
abstract interface class ProfileApi {
  Future<Me> getMe();
  Future<Me> updateNames({String? firstName, String? lastName});

  /// Formation, année de naissance, centres d'intérêt (null efface).
  Future<Me> updateAbout({
    String? studyProgram,
    int? birthYear,
    required List<String> interests,
    String? bio,
    CarpoolPreferences preferences = const CarpoolPreferences(),
  });

  /// Prénom et photo visibles, ou non, dans le classement du campus.
  Future<Me> setLeaderboardVisible(bool visible);

  /// Photo de profil (JPEG ou PNG déjà réduite par l'app).
  Future<Me> setPhoto(Uint8List bytes, String contentType);
  Future<void> removePhoto();

  /// Octets d'une photo de profil (`photoUrl`), avec le jeton.
  Future<Uint8List> photo(String url);

  /// Profil d'une personne croisée ; 404 sinon.
  Future<PublicProfile> publicProfile(String userId);
  Future<Me> setAddress(String address);

  /// Adresses existantes proposées pendant la saisie (Base Adresse Nationale).
  Future<List<String>> suggestAddresses(String query);
  Future<Me> setVehicle(Vehicle vehicle);
  Future<void> removeVehicle();
  Future<Me> setRoleMode(RoleMode mode);
  Future<Me> setDefaultNavApp(String app);
  Future<Me> setStep(OnboardingStep step, StepStatus status);
  Future<List<Pause>> listPauses();
  Future<Pause> addPause(PauseDraft pause);
  Future<void> removePause(String id);
}

class DioProfileApi implements ProfileApi {
  const DioProfileApi(this._dio);

  final Dio _dio;
  static const _me = '/api/v1/me';

  Future<Me> _me$(Future<Response<Map<String, dynamic>>> Function() call) =>
      guardApi(() async => Me.fromJson((await call()).data!));

  @override
  Future<Me> getMe() => _me$(() => _dio.get(_me));

  @override
  Future<Me> updateNames({String? firstName, String? lastName}) =>
      _me$(() => _dio.patch(_me, data: {'firstName': ?firstName, 'lastName': ?lastName}));

  @override
  Future<Me> updateAbout({
    String? studyProgram,
    int? birthYear,
    required List<String> interests,
    String? bio,
    CarpoolPreferences preferences = const CarpoolPreferences(),
  }) => _me$(
    () => _dio.patch(
      _me,
      data: {
        'studyProgram': studyProgram,
        'birthYear': birthYear,
        'interests': interests,
        'bio': bio,
        'preferences': preferences.toJson(),
      },
    ),
  );

  @override
  Future<Me> setLeaderboardVisible(bool visible) =>
      _me$(() => _dio.patch(_me, data: {'leaderboardVisible': visible}));

  @override
  Future<Me> setPhoto(Uint8List bytes, String contentType) => _me$(
    () => _dio.put(
      '$_me/photo',
      data: Stream.fromIterable([bytes]),
      options: Options(
        contentType: contentType,
        headers: {Headers.contentLengthHeader: bytes.length},
      ),
    ),
  );

  @override
  Future<void> removePhoto() => guardApi(() => _dio.delete<void>('$_me/photo'));

  @override
  Future<Uint8List> photo(String url) => guardApi(() async {
    final response = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  });

  @override
  Future<PublicProfile> publicProfile(String userId) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/users/$userId/public');
    return PublicProfile.fromJson(response.data!);
  });

  @override
  Future<Me> setAddress(String address) =>
      _me$(() => _dio.put('$_me/address', data: {'address': address}));

  @override
  Future<List<String>> suggestAddresses(String query) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/addresses',
      queryParameters: {'q': query},
    );
    return [
      for (final s in response.data!['suggestions'] as List<dynamic>)
        (s as Map<String, dynamic>)['label'] as String,
    ];
  });

  @override
  Future<Me> setVehicle(Vehicle vehicle) =>
      _me$(() => _dio.put('$_me/vehicle', data: vehicle.toJson()));

  @override
  Future<void> removeVehicle() => guardApi(() => _dio.delete<void>('$_me/vehicle'));

  @override
  Future<Me> setRoleMode(RoleMode mode) =>
      _me$(() => _dio.patch('$_me/preferences', data: {'roleMode': mode.wire}));

  @override
  Future<Me> setDefaultNavApp(String app) =>
      _me$(() => _dio.patch('$_me/preferences', data: {'defaultNavApp': app}));

  @override
  Future<Me> setStep(OnboardingStep step, StepStatus status) =>
      _me$(() => _dio.put('$_me/onboarding/${step.name}', data: {'status': status.name}));

  @override
  Future<List<Pause>> listPauses() => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>('$_me/pauses');
    return [
      for (final p in response.data!['pauses'] as List<dynamic>)
        Pause.fromJson(p as Map<String, dynamic>),
    ];
  });

  @override
  Future<Pause> addPause(PauseDraft pause) => guardApi(() async {
    final response = await _dio.post<Map<String, dynamic>>('$_me/pauses', data: pause.toJson());
    return Pause.fromJson(response.data!);
  });

  @override
  Future<void> removePause(String id) => guardApi(() => _dio.delete<void>('$_me/pauses/$id'));
}

final profileApiProvider = Provider<ProfileApi>(
  (ref) => ref.watch(demoProvider) ?? DioProfileApi(ref.watch(dioProvider)),
);
