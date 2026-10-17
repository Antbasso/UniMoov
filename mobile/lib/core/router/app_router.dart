import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/chat/presentation/conversation_screen.dart';
import '../../features/chat/presentation/conversations_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/splash_screen.dart';
import '../../features/home/presentation/welcome_screen.dart';
import '../../features/notifications/presentation/notification_settings_screen.dart';
import '../../features/profile/presentation/me_controller.dart';
import '../../features/profile/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_edit_screens.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/proposals/presentation/alternatives_screen.dart';
import '../../features/proposals/presentation/proposal_screen.dart';
import '../../features/proposals/presentation/search_screen.dart';
import '../../features/rides/presentation/departure_screen.dart';
import '../../features/rides/presentation/location_screen.dart';
import '../../features/rides/presentation/meeting_point_screen.dart';
import '../../features/rides/presentation/ride_screen.dart';
import '../../features/rides/presentation/suggestions_screen.dart';
import '../../features/trust/domain/trust.dart';
import '../../features/trust/presentation/dispute_screen.dart';
import '../../features/trust/presentation/reliability_screen.dart';
import '../../features/wallet/presentation/wallet_screen.dart';
import '../../features/schedule/presentation/schedule_screen.dart';
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
          GoRoute(path: 'reliability', builder: (_, _) => const ReliabilityScreen()),
          GoRoute(path: 'notifications', builder: (_, _) => const NotificationSettingsScreen()),
          GoRoute(
            path: 'schedule',
            builder: (_, _) => const ScheduleScreen(),
            routes: [
              GoRoute(path: 'ics', builder: (_, _) => const EditIcsScreen()),
              GoRoute(path: 'manual', builder: (_, _) => const EditManualScheduleScreen()),
            ],
          ),
        ],
      ),
      GoRoute(path: AppRoutes.search, builder: (_, _) => const SearchScreen()),
      GoRoute(path: AppRoutes.wallet, builder: (_, _) => const WalletScreen()),
      GoRoute(
        path: AppRoutes.messages,
        builder: (_, _) => const ConversationsScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) => ConversationScreen(id: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/disputes/:rideId',
        builder: (_, state) {
          final reason = state.uri.queryParameters['reason'];
          return DisputeScreen(
            rideId: state.pathParameters['rideId']!,
            reason: DisputeReason.values.where((r) => r.wire == reason).firstOrNull,
          );
        },
      ),
      GoRoute(
        path: '/week/:week/proposals/:id',
        builder: (_, state) =>
            ProposalScreen(week: state.pathParameters['week']!, id: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'alternatives',
            builder: (_, state) => AlternativesScreen(id: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/rides/:id',
        builder: (_, state) => RideScreen(id: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'meeting-point',
            builder: (_, state) => MeetingPointScreen(id: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'suggestions',
            builder: (_, state) => SuggestionsScreen(id: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'departure',
            builder: (_, state) => DepartureScreen(id: state.pathParameters['id']!),
          ),
          GoRoute(path: 'location', builder: (_, _) => const LocationPermissionScreen()),
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
