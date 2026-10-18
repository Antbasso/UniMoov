import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../proposals/data/proposals_api.dart';
import '../../proposals/domain/proposal.dart';

/// Trajet en cours de la personne connectée (bandeau permanent, carte animée de l'accueil).
/// Relu chaque minute : le départ d'un conducteur arrive aussi quand l'app est ouverte.
final activeRideProvider = FutureProvider.autoDispose<Proposal?>((ref) async {
  final timer = Timer(const Duration(minutes: 1), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  final week = isoWeekOf(ref.watch(clockProvider)());
  final proposals = await ref.watch(proposalsApiProvider).week(week);
  return proposals
      .where((p) => p.rideStatus == 'in_progress' && p.myStatus == 'accepted')
      .firstOrNull;
}, retry: (retryCount, error) => null);
