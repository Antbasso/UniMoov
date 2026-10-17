import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/authenticated_dio.dart';

/// Export et suppression du compte (docs/api.md, « Profil » ; docs/rgpd.md).
abstract interface class AccountApi {
  /// Fichier JSON de toutes les données du compte.
  Future<Uint8List> exportData();

  /// Suppression définitive, confirmée par le mot de passe.
  Future<void> deleteAccount(String password);
}

class DioAccountApi implements AccountApi {
  const DioAccountApi(this._dio);

  final Dio _dio;

  @override
  Future<Uint8List> exportData() => guardApi(() async {
    final response = await _dio.get<Object>('/api/v1/me/export');
    return Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(response.data)),
    );
  });

  @override
  Future<void> deleteAccount(String password) =>
      guardApi(() => _dio.delete<void>('/api/v1/me', data: {'password': password}));
}

final accountApiProvider = Provider<AccountApi>((ref) => DioAccountApi(ref.watch(dioProvider)));
