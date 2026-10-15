import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../proposals/presentation/proposals_controller.dart';
import '../data/schedule_api.dart';
import '../domain/schedule.dart';

/// Emploi du temps : agenda connecté et/ou semaine type. Toute modification relance les
/// propositions côté serveur ; les semaines affichées sont rechargées.
class ScheduleController extends AsyncNotifier<ScheduleState> {
  ScheduleApi get _api => ref.read(scheduleApiProvider);

  @override
  Future<ScheduleState> build() async {
    final api = ref.watch(scheduleApiProvider);
    final (connection, manual) = await (api.getConnection(), api.getManual()).wait;
    return ScheduleState(connection: connection, manualDays: manual);
  }

  ScheduleState get _current =>
      state.value ?? const ScheduleState(connection: null, manualDays: []);

  void _refreshWeeks() => ref.invalidate(weekProposalsProvider);

  // Après chaque appel : l'écran a pu se fermer pendant l'attente (fin de l'onboarding).
  Future<void> connectIcs(String url) async {
    final connection = await _api.connectIcs(url.trim());
    if (!ref.mounted) return;
    state = AsyncData(ScheduleState(connection: connection, manualDays: _current.manualDays));
    _refreshWeeks();
  }

  Future<void> sync() async {
    final connection = await _api.sync();
    if (!ref.mounted) return;
    state = AsyncData(ScheduleState(connection: connection, manualDays: _current.manualDays));
    _refreshWeeks();
  }

  Future<void> disconnect() async {
    final connection = _current.connection;
    if (connection == null) return;
    await _api.disconnect(connection.id);
    if (!ref.mounted) return;
    state = AsyncData(ScheduleState(connection: null, manualDays: _current.manualDays));
    _refreshWeeks();
  }

  Future<void> setManual(List<ManualDay> days) async {
    final saved = await _api.setManual(days);
    if (!ref.mounted) return;
    state = AsyncData(ScheduleState(connection: _current.connection, manualDays: saved));
    _refreshWeeks();
  }
}

final scheduleProvider = AsyncNotifierProvider.autoDispose<ScheduleController, ScheduleState>(
  ScheduleController.new,
  retry: (retryCount, error) => null,
);
