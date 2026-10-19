import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/error_messages.dart';
import '../../../core/clock.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../schedule/domain/schedule.dart';
import '../domain/proposal.dart';
import 'alternatives_screen.dart';
import 'proposals_controller.dart';

/// Recherche manuelle (cahier §4) : jour, sens, heure facultative ; quota quotidien.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final DateTime _today = () {
    final now = ref.read(clockProvider)();
    return DateTime(now.year, now.month, now.day);
  }();
  late DateTime _day = _today;
  Direction _direction = Direction.toCampus;
  TimeOfDay? _time;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final state = ref.watch(searchProvider);
    final time = _time == null ? null : ManualDay.format(_time!.hour, _time!.minute);

    return UmPage(
      appBar: AppBar(),
      title: l10n.searchTitle,
      children: [
        Text(l10n.searchDayLabel, style: UmText.label.copyWith(color: c.ink)),
        const SizedBox(height: UmSpace.s2),
        // Calendrier des deux semaines à venir : on voit tout de suite quel jour on choisit.
        UmCalendar(
          first: _today,
          last: _today.add(const Duration(days: 13)),
          selected: _day,
          onSelected: (day) => setState(() => _day = day),
        ),
        const SizedBox(height: UmSpace.s4),
        SegmentedButton<Direction>(
          segments: [
            ButtonSegment(value: Direction.toCampus, label: Text(l10n.directionTo)),
            ButtonSegment(value: Direction.fromCampus, label: Text(l10n.directionFrom)),
          ],
          selected: {_direction},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _direction = s.first),
        ),
        const SizedBox(height: UmSpace.s4),
        UmButton(
          label: time == null ? l10n.searchNoTime : '${l10n.searchTimeOptional} : $time',
          icon: Icons.schedule_rounded,
          variant: UmButtonVariant.secondary,
          onPressed: _pickTime,
        ),
        const SizedBox(height: UmSpace.s4),
        UmButton(
          label: l10n.searchAction,
          icon: Icons.search_rounded,
          expand: true,
          loading: state.busy,
          onPressed: () => ref
              .read(searchProvider.notifier)
              .search(day: _day, direction: _direction, time: time),
        ),
        const SizedBox(height: UmSpace.s5),
        if (state.errorCode != null)
          UmErrorText(apiErrorMessage(l10n, state.errorCode))
        else if (state.results == null)
          Text(l10n.searchHint, style: UmText.body.copyWith(color: c.inkMuted))
        else if (state.results!.isEmpty)
          Text(l10n.searchEmpty, style: UmText.body.copyWith(color: c.inkMuted))
        else
          JoinableList(rides: state.results!),
      ],
    );
  }
}
