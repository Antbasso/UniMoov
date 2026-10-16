import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/authenticated_dio.dart';
import '../domain/wallet.dart';

abstract interface class WalletApi {
  Future<Wallet> wallet();

  /// `idempotencyKey` : la même clé ne recharge qu'une fois (double appui, requête rejouée).
  Future<Wallet> topup(int amountCents, String idempotencyKey);
}

/// Clé d'idempotence aléatoire (128 bits).
String newIdempotencyKey() {
  final random = Random.secure();
  return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

class DioWalletApi implements WalletApi {
  const DioWalletApi(this._dio);

  final Dio _dio;

  @override
  Future<Wallet> wallet() => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/wallet');
    return Wallet.fromJson(response.data!);
  });

  @override
  Future<Wallet> topup(int amountCents, String idempotencyKey) => guardApi(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/wallet/topups',
      data: {'amountCents': amountCents},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return Wallet.fromJson(response.data!['wallet'] as Map<String, dynamic>);
  });
}

final walletApiProvider = Provider<WalletApi>((ref) => DioWalletApi(ref.watch(dioProvider)));
