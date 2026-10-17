import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/session_controller.dart';
import '../data/account_api.dart';
import '../data/export_sharer.dart';

/// Actions RGPD du compte ; les erreurs ([ApiException]) remontent à l'écran.
class AccountActions {
  const AccountActions(this._ref);

  final Ref _ref;

  static const exportFileName = 'uni-moov-mes-donnees.json';

  Future<void> exportData({required String subject, Rect? origin}) async {
    final bytes = await _ref.read(accountApiProvider).exportData();
    await _ref
        .read(exportSharerProvider)
        .share(bytes, fileName: exportFileName, subject: subject, origin: origin);
  }

  /// Après suppression, la session locale est effacée : retour à l'accueil.
  Future<void> deleteAccount(String password) async {
    await _ref.read(accountApiProvider).deleteAccount(password);
    await _ref.read(sessionProvider.notifier).accountDeleted();
  }
}

final accountActionsProvider = Provider<AccountActions>(AccountActions.new);
