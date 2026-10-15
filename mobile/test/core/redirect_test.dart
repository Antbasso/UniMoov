import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/core/router/redirect.dart';
import 'package:unimoov/features/auth/presentation/session_controller.dart';
import 'package:unimoov/features/profile/domain/me.dart';

Me me({bool completed = false}) => Me(
  id: 'id',
  universityEmail: 'lea@etu.univ-smb.fr',
  firstName: 'Léa',
  lastName: 'Martin',
  home: null,
  roleMode: RoleMode.alwaysPassenger,
  vehicle: null,
  steps: const {},
  nextStep: completed ? null : OnboardingStep.profile,
  onboardingCompleted: completed,
  discoveryMode: true,
  pausedToday: false,
);

String? go(
  AsyncValue<SessionStatus> session,
  String location, {
  AsyncValue<Me?> profile = const AsyncLoading(),
}) => resolveRedirect(session: session, me: profile, location: location);

void main() {
  const signedIn = AsyncData(SessionStatus.signedIn);
  const signedOut = AsyncData(SessionStatus.signedOut);

  test('session inconnue : écran d’attente', () {
    expect(go(const AsyncLoading(), AppRoutes.home), AppRoutes.splash);
    expect(go(const AsyncLoading(), AppRoutes.splash), isNull);
  });

  test('déconnecté : seules les pages publiques', () {
    expect(go(signedOut, AppRoutes.home), AppRoutes.welcome);
    expect(go(signedOut, AppRoutes.profile), AppRoutes.welcome);
    expect(go(signedOut, AppRoutes.splash), AppRoutes.welcome);
    expect(go(signedOut, AppRoutes.login), isNull);
    expect(go(signedOut, AppRoutes.signup), isNull);
  });

  test('connecté, profil en chargement ou en erreur : écran d’attente', () {
    expect(go(signedIn, AppRoutes.login), AppRoutes.splash);
    expect(
      go(signedIn, AppRoutes.home, profile: AsyncError(Exception('x'), StackTrace.empty)),
      AppRoutes.splash,
    );
  });

  test('onboarding incomplet : on y revient, d’où que l’on vienne', () {
    final profile = AsyncData<Me?>(me());
    expect(go(signedIn, AppRoutes.home, profile: profile), AppRoutes.onboarding);
    expect(go(signedIn, AppRoutes.splash, profile: profile), AppRoutes.onboarding);
    expect(go(signedIn, AppRoutes.onboarding, profile: profile), isNull);
  });

  test('onboarding terminé : accueil, profil accessible', () {
    final profile = AsyncData<Me?>(me(completed: true));
    expect(go(signedIn, AppRoutes.onboarding, profile: profile), AppRoutes.home);
    expect(go(signedIn, AppRoutes.login, profile: profile), AppRoutes.home);
    expect(go(signedIn, AppRoutes.profileVehicle, profile: profile), isNull);
    expect(go(signedIn, AppRoutes.home, profile: profile), isNull);
  });
}
