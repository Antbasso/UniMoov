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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.weekTitle, style: UmText.h2.copyWith(color: c.ink)),
        ),
        const SizedBox(height: UmSpace.s3),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(l10n.weekThis)),
            ButtonSegment(value: true, label: Text(l10n.weekNext)),
          ],
          selected: {_next},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => setState(() => _next = selection.first),
        ),
        const SizedBox(height: UmSpace.s4),
        ...switch (proposals) {
          AsyncData(:final value) when value.isEmpty => [
            _Empty(onSearch: () => context.push(AppRoutes.search)),
          ],
          AsyncData(:final value) => _byDay(context, l10n, week, value),
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
        const SizedBox(height: UmSpace.s4),
        UmButton(
          label: l10n.searchAction,
          icon: Icons.search_rounded,
          variant: UmButtonVariant.secondary,
          onPressed: () => context.push(AppRoutes.search),
        ),
      ],
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
                style: UmText.h3.copyWith(color: c.ink),
              ),
            ),
          ),
        );
      }
      final (from, to) = endpoints(l10n, p.direction, driver: p.isDriver);
      final time = formatTime(p.time, l10n.localeName);
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: UmSpace.s3),
          child: UmRideCard(
            from: from,
            to: to,
            time: time,
            driverFirstName: p.driver?.firstName ?? '',
            seatsLeft: p.seatsLeft,
            status: rideStatusOf(p),
            role: p.isDriver ? UmRideRole.driver : UmRideRole.passenger,
            live: p.rideStatus == 'in_progress',
            metaText: p.isDriver ? l10n.rideMetaDriverShort(p.seatsTaken) : null,
            actionLabel: l10n.see,
            actionVariant: UmButtonVariant.secondary,
            onAction: () => context.push(AppRoutes.proposal(week, p.id)),
          ),
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
        if (noSchedule) ...[
          const SizedBox(height: UmSpace.s3),
          UmButton(
            label: l10n.addSchedule,
            onPressed: () => context.push(AppRoutes.profileSchedule),
          ),
        ],
      ],
    );
  }
}
