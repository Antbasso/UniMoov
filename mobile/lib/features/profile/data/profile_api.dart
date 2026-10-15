import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/authenticated_dio.dart';
import '../domain/me.dart';

/// Routes du profil (docs/api.md, « Profil ») ; toutes exigent un JWT.
abstract interface class ProfileApi {
  Future<Me> getMe();
  Future<Me> updateNames({String? firstName, String? lastName});
  Future<Me> setAddress(String address);
  Future<Me> setVehicle(Vehicle vehicle);
  Future<void> removeVehicle();
  Future<Me> setRoleMode(RoleMode mode);
  Future<Me> setStep(OnboardingStep step, StepStatus status);
  Future<List<Pause>> listPauses();
  Future<Pause> addPause(DateTime startsOn, DateTime endsOn, int? everyWeeks);
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
  Future<Me> setAddress(String address) =>
      _me$(() => _dio.put('$_me/address', data: {'address': address}));

  @override
  Future<Me> setVehicle(Vehicle vehicle) =>
      _me$(() => _dio.put('$_me/vehicle', data: vehicle.toJson()));

  @override
  Future<void> removeVehicle() => guardApi(() => _dio.delete<void>('$_me/vehicle'));

  @override
  Future<Me> setRoleMode(RoleMode mode) =>
      _me$(() => _dio.patch('$_me/preferences', data: {'roleMode': mode.wire}));

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
  Future<Pause> addPause(DateTime startsOn, DateTime endsOn, int? everyWeeks) => guardApi(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_me/pauses',
      data: Pause.requestBody(startsOn, endsOn, everyWeeks),
    );
    return Pause.fromJson(response.data!);
  });

  @override
  Future<void> removePause(String id) => guardApi(() => _dio.delete<void>('$_me/pauses/$id'));
}

final profileApiProvider = Provider<ProfileApi>((ref) => DioProfileApi(ref.watch(dioProvider)));
