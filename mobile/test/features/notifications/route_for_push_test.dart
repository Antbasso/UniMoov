import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/core/router/redirect.dart';
import 'package:unimoov/features/notifications/presentation/push_controller.dart';

void main() {
  const id = '6f1c2a3b-4d5e-4f60-8a7b-9c0d1e2f3a4b';

  test('ouvre l’écran attendu avec un identifiant valide', () {
    expect(
      routeForPush({'type': 'chat_message', 'conversationId': id}),
      AppRoutes.conversation(id),
    );
    expect(routeForPush({'type': 'ride_reminder', 'rideId': id}), AppRoutes.ride(id));
    expect(routeForPush({'type': 'ride_requested', 'rideId': id}), AppRoutes.home);
  });

  test('identifiant forgé (chemin, remontée) : notification ignorée', () {
    expect(routeForPush({'type': 'ride_reminder', 'rideId': '$id/departure'}), isNull);
    expect(routeForPush({'type': 'chat_message', 'conversationId': '../../wallet'}), isNull);
    expect(routeForPush({'type': 'ride_cancelled', 'rideId': ''}), isNull);
    expect(routeForPush({'type': 'inconnu'}), isNull);
  });
}
