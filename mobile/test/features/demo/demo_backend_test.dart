import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/core/api/api_client.dart';
import 'package:unimoov/features/demo/data/demo_backend.dart';
import 'package:unimoov/features/demo/data/demo_world.dart';
import 'package:unimoov/features/proposals/domain/proposal.dart';
import 'package:unimoov/features/rides/domain/ride.dart';
import 'package:unimoov/features/wallet/domain/wallet.dart';

void main() {
  final now = DateTime(2026, 10, 15, 10);
  DemoBackend backend() => DemoBackend(clock: () => now, latency: Duration.zero)..signInDemo();

  test(
    'semaine de Camille : trajet en cours, à conduire, propositions, demande de place',
    () async {
      final b = backend();
      final week = await b.week(isoWeekOf(now));
      expect(
        week.map((p) => p.id),
        containsAll(['demo-live', 'demo-drive', 'demo-offer', 'demo-requests']),
      );
      expect(week.firstWhere((p) => p.id == 'demo-live').state, ProposalState.confirmed);
      final requests = week.firstWhere((p) => p.id == 'demo-requests');
      expect(requests.isDriver, isTrue);
      expect(requests.passengers.any((p) => p.isRequest), isTrue);
      expect((await b.getMe()).onboardingCompleted, isTrue);
    },
  );

  test('solde insuffisant pour le trajet long, puis recharge', () async {
    final b = backend();
    await expectLater(
      b.accept('demo-expensive'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'insufficient_funds')),
    );
    await b.topup(1000, 'cle-1');
    expect((await b.accept('demo-expensive')).myStatus, 'accepted');
  });

  test('retrait : IBAN contrôlé, solde mis à jour', () async {
    final b = backend();
    await b.topup(2000, 'cle-1');
    const bad = PayoutRequest(
      amountCents: 1000,
      iban: 'FR7630006000011234567890188',
      holderName: 'Camille',
    );
    await expectLater(b.payout(bad, 'r1'), throwsA(isA<ApiException>()));
    final before = (await b.wallet()).balanceCents;
    const good = PayoutRequest(
      amountCents: 1000,
      iban: 'FR7630006000011234567890189',
      holderName: 'Camille',
    );
    expect((await b.payout(good, 'r2')).balanceCents, before - 1000);
  });

  testWidgets('trajet en cours simulé : le conducteur arrive, présence, arrivée, paiement', (
    tester,
  ) async {
    final b = DemoBackend(
      clock: () => now,
      latency: Duration.zero,
      tick: const Duration(seconds: 1),
    )..signInDemo();
    final heldBefore = (await b.wallet()).heldCents;
    expect(heldBefore, greaterThan(0));
    final connection = await b.live.connect('demo-live');
    final events = <LiveEvent>[];
    connection.events.listen(events.add);
    int? closed;
    unawaited(connection.closeCode.then((code) => closed = code));
    for (var i = 0; i < 120 && closed == null; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(events.whereType<LivePosition>(), isNotEmpty);
    expect(events.whereType<LivePresence>().map((e) => e.userId), contains(demoMeId));
    expect(events.whereType<LivePassengerDone>().single.arrived, isTrue);
    expect(events.whereType<LiveStatus>().single.status, 'completed');
    expect(closed, 4410);
    final wallet = await b.wallet();
    expect(wallet.heldCents, 0);
    expect(wallet.history.first.kind, 'ride_charge');
    expect((await b.ride('demo-live')).stopOf(demoMeId)!.arrived, isTrue);
  });

  testWidgets('trajet conduit : départ, montées, arrivées, rémunération', (tester) async {
    final b = DemoBackend(
      clock: () => now,
      latency: Duration.zero,
      tick: const Duration(seconds: 1),
    )..signInDemo();
    final balance = (await b.wallet()).balanceCents;
    await b.start('demo-drive');
    final connection = await b.live.connect('demo-drive');
    int? closed;
    unawaited(connection.closeCode.then((code) => closed = code));
    for (final id in ['ines', 'hugo']) {
      await b.pickedUp('demo-drive', id);
    }
    for (var i = 0; i < 30 && closed == null; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(closed, 4410);
    final ride = await b.ride('demo-drive');
    expect(ride.completed, isTrue);
    expect((await b.wallet()).balanceCents, greaterThan(balance));
  });
}
