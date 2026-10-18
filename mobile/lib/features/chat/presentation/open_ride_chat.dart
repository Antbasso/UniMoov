import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/redirect.dart';
import '../data/chat_api.dart';

/// Ouvre la conversation du trajet dans l'onglet Messages (créée à la confirmation, ou
/// maintenant s'il n'y en a pas encore). Une erreur de l'API remonte à l'appelant.
Future<void> openRideChat(BuildContext context, WidgetRef ref, String rideId) async {
  final router = GoRouter.of(context);
  final chat = await ref.read(chatApiProvider).rideConversation(rideId);
  router.go(AppRoutes.conversation(chat.id));
}
