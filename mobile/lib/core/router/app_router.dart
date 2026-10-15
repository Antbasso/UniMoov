import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_screen.dart';

abstract final class AppRoutes {
  static const home = '/';
}

final appRouterProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    initialLocation: AppRoutes.home,
    routes: [GoRoute(path: AppRoutes.home, builder: (context, state) => const HomeScreen())],
  ),
);
