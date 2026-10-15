import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/splash_screen.dart';
import '../../features/home/presentation/welcome_screen.dart';
import '../../features/profile/presentation/me_controller.dart';
import '../../features/profile/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_edit_screens.dart';
import '../../features/profile/presentation/profile_screen.dart';
import 'redirect.dart';

export 'redirect.dart' show AppRoutes;

final appRouterProvider = Provider<GoRouter>((ref) {
  // Réévalue la redirection seulement quand ce qui la décide change : statut de session,
  // profil chargé ou non, onboarding terminé. Une simple modification du profil ne doit pas
  // relancer le routeur (il rétablirait la page qu'on vient de quitter).
  final refresh = ValueNotifier(0);
  ref
    ..listen(sessionProvider.select((s) => (s.isLoading, s.value)), (_, _) => refresh.value++)
    ..listen(
      meProvider.select((m) => (m.hasError, m.value == null, m.value?.onboardingCompleted)),
      (_, _) => refresh.value++,
    );

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => resolveRedirect(
      session: ref.read(sessionProvider),
      me: ref.read(meProvider),
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: AppRoutes.welcome, builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: AppRoutes.signup, builder: (_, _) => const SignupScreen()),
      GoRoute(path: AppRoutes.onboarding, builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: AppRoutes.home, builder: (_, _) => const HomeScreen()),
      GoRoute(
        path: AppRoutes.profile,
        builder: (_, _) => const ProfileScreen(),
        routes: [
          GoRoute(path: 'address', builder: (_, _) => const EditAddressScreen()),
          GoRoute(path: 'vehicle', builder: (_, _) => const EditVehicleScreen()),
          GoRoute(path: 'role', builder: (_, _) => const EditRoleScreen()),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
