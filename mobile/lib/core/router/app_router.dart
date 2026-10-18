import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/delete_account_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/chat/presentation/conversation_info_screen.dart';
import '../../features/chat/presentation/conversation_screen.dart';
import '../../features/chat/presentation/conversations_screen.dart';
import '../../features/home/presentation/app_shell.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/splash_screen.dart';
import '../../features/home/presentation/welcome_screen.dart';
import '../../features/notifications/presentation/notification_settings_screen.dart';
import '../../features/profile/presentation/about_screen.dart';
import '../../features/profile/presentation/me_controller.dart';
import '../../features/profile/presentation/public_profile_screen.dart';
import '../../features/profile/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_edit_screens.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/proposals/presentation/alternatives_screen.dart';
import '../../features/proposals/presentation/proposal_screen.dart';
import '../../features/proposals/presentation/search_screen.dart';
import '../../features/rides/presentation/departure_screen.dart';
import '../../features/rides/presentation/history_screen.dart';
import '../../features/rides/presentation/location_screen.dart';
import '../../features/rides/presentation/meeting_point_screen.dart';
import '../../features/rides/presentation/ride_screen.dart';
import '../../features/rides/presentation/suggestions_screen.dart';
import '../../features/trust/domain/trust.dart';
import '../../features/trust/presentation/dispute_screen.dart';
import '../../features/trust/presentation/reliability_screen.dart';
import '../../features/trust/presentation/charter_screen.dart';
import '../../features/achievements/presentation/achievements_screen.dart';
import '../../features/wallet/presentation/payout_screen.dart';
import '../../features/wallet/presentation/wallet_screen.dart';
import '../../features/schedule/presentation/schedule_screen.dart';
import 'redirect.dart';

export 'redirect.dart' show AppRoutes;

final _rootKey = GlobalKey<NavigatorState>();

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
    navigatorKey: _rootKey,
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
      GoRoute(path: AppRoutes.charter, builder: (_, _) => const CharterScreen()),
      // Onglets : messages, accueil, profil (barre du bas, trajet en cours visible partout).
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.messages,
                builder: (_, _) => const ConversationsScreen(),
                routes: [
                  // Conversation en plein écran, sans la barre (place pour le clavier).
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: _rootKey,
                    builder: (_, state) => ConversationScreen(id: state.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'info',
                        parentNavigatorKey: _rootKey,
                        builder: (_, state) =>
                            ConversationInfoScreen(id: state.pathParameters['id']!),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.home, builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (_, _) => const ProfileScreen(),
                // Sous-pages en plein écran, sans la barre d'onglets.
                routes: [
                  GoRoute(
                    path: 'address',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const EditAddressScreen(),
                  ),
                  GoRoute(
                    path: 'vehicle',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const EditVehicleScreen(),
                  ),
                  GoRoute(
                    path: 'role',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const EditRoleScreen(),
                  ),
                  GoRoute(
                    path: 'about',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const EditAboutScreen(),
                  ),
                  GoRoute(
                    path: 'history',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const HistoryScreen(),
                  ),
                  GoRoute(
                    path: 'reliability',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const ReliabilityScreen(),
                  ),
                  GoRoute(
                    path: 'achievements',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const AchievementsScreen(),
                  ),
                  GoRoute(
                    path: 'notifications',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const NotificationSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'delete',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const DeleteAccountScreen(),
                  ),
                  GoRoute(
                    path: 'schedule',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const ScheduleScreen(),
                    routes: [
                      // Au-dessus de l'écran de l'agenda (navigateur racine), sinon ils
                      // s'ouvraient dessous, sans rien montrer.
                      GoRoute(
                        path: 'ics',
                        parentNavigatorKey: _rootKey,
                        builder: (_, _) => const EditIcsScreen(),
                      ),
                      GoRoute(
                        path: 'manual',
                        parentNavigatorKey: _rootKey,
                        builder: (_, _) => const EditManualScheduleScreen(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: AppRoutes.search, builder: (_, _) => const SearchScreen()),
      GoRoute(
        path: '/users/:id',
        builder: (_, state) => PublicProfileScreen(userId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.wallet,
        builder: (_, _) => const WalletScreen(),
        routes: [GoRoute(path: 'payout', builder: (_, _) => const PayoutScreen())],
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
