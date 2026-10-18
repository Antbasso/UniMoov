import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/achievements_api.dart';
import '../domain/achievements.dart';

final achievementsProvider = FutureProvider.autoDispose<Achievements>(
  (ref) => ref.watch(achievementsApiProvider).achievements(),
  retry: (retryCount, error) => null,
);

final leaderboardProvider = FutureProvider.autoDispose<Leaderboard>(
  (ref) => ref.watch(achievementsApiProvider).leaderboard(),
  retry: (retryCount, error) => null,
);
