import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/session_controller.dart';
import '../../features/profile/domain/me.dart';
import '../../features/trust/domain/trust.dart';

abstract final class AppRoutes {
  static const splash = '/';
  static const welcome = '/welcome';
  static const login = '/login';
  static const signup = '/signup';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const profile = '/profile';
  static const profileAddress = '/profile/address';
  static const profileVehicle = '/profile/vehicle';
  static const profileRole = '/profile/role';
  static const profileSchedule = '/profile/schedule';
  static const history = '/profile/history';
  static const profileAbout = '/profile/about';
  static String person(String userId) => '/users/$userId';
  static const profileScheduleIcs = '/profile/schedule/ics';
  static const profileScheduleManual = '/profile/schedule/manual';
  static const search = '/search';
  static String proposal(String week, String id) => '/week/$week/proposals/$id';
  static String alternatives(String week, String id) => '/week/$week/proposals/$id/alternatives';
  static String ride(String id) => '/rides/$id';
  static String rideMeetingPoint(String id) => '/rides/$id/meeting-point';
  static String rideSuggestions(String id) => '/rides/$id/suggestions';
  static String rideDeparture(String id) => '/rides/$id/departure';
  static String rideLocation(String id) => '/rides/$id/location';
  static const wallet = '/wallet';
  static const walletPayout = '/wallet/payout';
  static const reliability = '/profile/reliability';
  static const achievements = '/profile/achievements';
  static const leaderboard = '/leaderboard';
  static const notificationSettings = '/profile/notifications';
  static const deleteAccount = '/profile/delete';
  static const messages = '/messages';
  static const charter = '/charter';
  static String conversation(String id) => '/messages/$id';
  static String conversationInfo(String id) => '/messages/$id/info';

  /// Litige sur un trajet ; route à part, car un passager qui a annulé n'a plus accès au trajet.
  static String dispute(String rideId, {DisputeReason? reason}) => Uri(
    path: '/disputes/$rideId',
    queryParameters: reason == null ? null : {'reason': reason.wire},
  ).toString();

  static const public = {welcome, login, signup, charter};
  static const entry = {splash, welcome, login, signup, onboarding};
}

/// Où envoyer l'utilisateur selon sa session et son onboarding (`null` : rester).
/// Fonction pure : testée sans widget.
String? resolveRedirect({
  required AsyncValue<SessionStatus> session,
  required AsyncValue<Me?> me,
  required String location,
}) {
  String? goTo(String target) => location == target ? null : target;

  final status = session.value;
  if (status == null) return goTo(AppRoutes.splash);
  if (status == SessionStatus.signedOut) {
    return AppRoutes.public.contains(location) ? null : AppRoutes.welcome;
  }

  final profile = me.value;
  // Profil en chargement ou en erreur : l'écran d'attente gère les deux états.
  if (profile == null) return goTo(AppRoutes.splash);
  // Reprise de l'onboarding là où l'utilisateur l'a laissé.
  if (!profile.onboardingCompleted) return goTo(AppRoutes.onboarding);
  return AppRoutes.entry.contains(location) ? AppRoutes.home : null;
}
