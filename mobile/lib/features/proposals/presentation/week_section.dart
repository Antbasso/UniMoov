import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/clock.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../schedule/presentation/schedule_controller.dart';
import '../domain/proposal.dart';
import 'formatting.dart';
import 'proposals_controller.dart';

/// « Ta semaine » : propositions de la semaine en cours ou suivante, groupées par jour.
class WeekSection extends ConsumerStatefulWidget {
  const WeekSection({super.key});

  @override
  ConsumerState<WeekSection> createState() => _WeekSectionState();
}

class _WeekSectionState extends ConsumerState<WeekSection> {
  bool _next = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final now = ref.watch(clockProvider)();
    final week = isoWeekOf(_next ? now.add(const Duration(days: 7)) : now);
    final proposals = ref.watch(weekProposalsProvider(week));

    final value = proposals.value;
    // Trajet en cours d'abord, à part ; les trajets terminés passent dans l'historique (profil).
    final live = value?.where(_isLive).toList() ?? const <Proposal>[];
    final upcoming = value?.where((p) => !_isLive(p) && p.rideStatus != 'completed').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in live) ...[
          _card(context, l10n, week, p),
          const SizedBox(height: UmSpace.s5),
        ],
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(l10n.weekTitle, style: UmText.h2.copyWith(color: c.ink)),
              ),
            ),
            IconButton(
              tooltip: l10n.searchAction,
              icon: Icon(Icons.search_rounded, color: c.brandStrong),
              onPressed: () => context.push(AppRoutes.search),
            ),
          ],
        ),
        const SizedBox(height: UmSpace.s2),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(l10n.weekThis)),
            ButtonSegment(value: true, label: Text(l10n.weekNext)),
          ],
          selected: {_next},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => setState(() => _next = selection.first),
        ),
        const SizedBox(height: UmSpace.s3),
        ...switch (proposals) {
          AsyncData() when upcoming!.isEmpty && live.isEmpty => [
            _Empty(onSearch: () => context.push(AppRoutes.search)),
          ],
          AsyncData() => _byDay(context, l10n, week, upcoming!),
          AsyncError(:final error) => [
            UmErrorText(apiErrorMessage(l10n, error is ApiException ? error.code : null)),
            const SizedBox(height: UmSpace.s2),
            UmButton(
              label: l10n.retry,
              variant: UmButtonVariant.ghost,
              onPressed: () => ref.invalidate(weekProposalsProvider(week)),
            ),
          ],
          _ => [
            Semantics(
              label: l10n.loading,
              child: LinearProgressIndicator(color: c.brand, backgroundColor: c.lavender),
            ),
          ],
        },
      ],
    );
  }

  static bool _isLive(Proposal p) => p.rideStatus == 'in_progress' && p.myStatus == 'accepted';

  Widget _card(BuildContext context, AppLocalizations l10n, String week, Proposal p) {
    final (from, to) = endpoints(l10n, p.direction, driver: p.isDriver);
    return UmRideCard(
      from: from,
      to: to,
      time: formatTime(p.time, l10n.localeName),
      driverFirstName: p.driver?.firstName ?? '',
      seatsLeft: p.seatsLeft,
      status: rideStatusOf(p),
      role: p.isDriver ? UmRideRole.driver : UmRideRole.passenger,
      live: _isLive(p),
      meta: [
        if (p.isDriver)
          (Icons.people_outline_rounded, l10n.rideSeatsTaken(p.seatsTaken, p.seatsTotal))
        else if (p.driver != null)
          (Icons.person_outline_rounded, p.driver!.firstName),
      ],
      onTap: () => context.push(AppRoutes.proposal(week, p.id)),
    );
  }

  List<Widget> _byDay(
    BuildContext context,
    AppLocalizations l10n,
    String week,
    List<Proposal> list,
  ) {
    final c = context.umColors;
    final widgets = <Widget>[];
    DateTime? currentDay;
    for (final p in list) {
      if (p.day != currentDay) {
        currentDay = p.day;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: UmSpace.s3, bottom: UmSpace.s2),
            child: Semantics(
              header: true,
              child: Text(
                formatDay(p.day, l10n.localeName),
                style: UmText.label.copyWith(color: c.inkMuted),
              ),
            ),
          ),
        );
      }
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: UmSpace.s3),
          child: _card(context, l10n, week, p),
        ),
      );
    }
    return widgets;
  }
}

class _Empty extends ConsumerWidget {
  const _Empty({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final schedule = ref.watch(scheduleProvider).value;
    final noSchedule = schedule != null && schedule.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          noSchedule ? l10n.weekEmptyNoSchedule : l10n.weekEmpty,
          style: UmText.body.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: UmSpace.s3),
        if (noSchedule)
          UmButton(
            label: l10n.addSchedule,
            onPressed: () => context.push(AppRoutes.profileSchedule),
          )
        else
          UmButton(
            label: l10n.searchAction,
            icon: Icons.search_rounded,
            variant: UmButtonVariant.secondary,
            onPressed: onSearch,
          ),
      ],
    );
  }
}
