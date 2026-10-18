import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/clock.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/me.dart';
import 'me_controller.dart';
import 'pause_format.dart';

export 'pause_format.dart' show formatPauseDate;

Future<void> showPauseSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const PauseSheet(),
);

enum PauseMode { dates, days, repeat }

/// Fréquences proposées pour « Répéter » : semaines puis mois.
const pauseFrequencies = <PauseRepeat>[
  RepeatWeekly(1),
  RepeatWeekly(2),
  RepeatWeekly(3),
  RepeatWeekly(4),
  RepeatMonthly(1),
  RepeatMonthly(2),
  RepeatMonthly(3),
];

/// Programmer une pause comme un événement d'agenda (cahier §12) : des dates, certains jours
/// chaque semaine, ou une période qui se répète, jusqu'à une date.
class PauseSheet extends ConsumerStatefulWidget {
  const PauseSheet({super.key});

  @override
  ConsumerState<PauseSheet> createState() => _PauseSheetState();
}

class _PauseSheetState extends ConsumerState<PauseSheet> {
  PauseMode _mode = PauseMode.dates;
  DateTimeRange? _range;
  final Set<int> _weekdays = {};
  PauseRepeat _frequency = pauseFrequencies[1];
  DateTime? _until;
  bool _busy = false;
  String? _errorCode;

  DateTime get _today {
    final now = ref.read(clockProvider)();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: _today,
      lastDate: _today.add(const Duration(days: 365)),
      initialDateRange: _range,
    );
    if (range != null) setState(() => _range = range);
  }

  Future<void> _pickUntil() async {
    final first = _mode == PauseMode.repeat ? (_range?.end ?? _today) : _today;
    final until = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: _today.add(const Duration(days: 365)),
      initialDate: _until != null && !_until!.isBefore(first)
          ? _until!
          : first.add(const Duration(days: 90)),
    );
    if (until != null) setState(() => _until = until);
  }

  /// Pause décrite par le formulaire, `null` tant qu'il manque quelque chose.
  PauseDraft? get _draft {
    switch (_mode) {
      case PauseMode.dates:
        final range = _range;
        return range == null ? null : PauseDraft(startsOn: range.start, endsOn: range.end);
      case PauseMode.days:
        final until = _until;
        if (_weekdays.isEmpty || until == null) return null;
        return PauseDraft(
          startsOn: _today,
          endsOn: _today,
          repeat: RepeatDays({..._weekdays}),
          repeatUntil: until,
        );
      case PauseMode.repeat:
        final range = _range;
        final until = _until;
        if (range == null || until == null) return null;
        return PauseDraft(
          startsOn: range.start,
          endsOn: range.end,
          repeat: _frequency,
          repeatUntil: until,
        );
    }
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || !draft.fitsPeriod) return;
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    try {
      await ref.read(pausesProvider.notifier).add(draft);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorCode = error.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _frequencyLabel(PauseRepeat repeat, AppLocalizations l10n) {
    final text = switch (repeat) {
      RepeatWeekly(:final every) => l10n.pauseEveryWeeks(every),
      RepeatMonthly(:final every) => l10n.pauseEveryMonths(every),
      RepeatDays() => '',
    };
    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final locale = l10n.localeName;
    final range = _range;
    final until = _until;
    final draft = _draft;
    final tooLong = draft != null && !draft.fitsPeriod;

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: UmSpace.s4, bottom: UmSpace.s2),
      child: Text(text, style: UmText.label.copyWith(color: c.ink)),
    );

    final rangeButton = UmButton(
      label: range == null
          ? (_mode == PauseMode.repeat ? l10n.pauseChooseFirst : l10n.pauseChooseDates)
          : l10n.pauseRange(
              formatPauseDate(range.start, locale),
              formatPauseDate(range.end, locale),
            ),
      icon: Icons.date_range_rounded,
      variant: UmButtonVariant.secondary,
      expand: true,
      onPressed: _pickRange,
    );
    final untilButton = UmButton(
      label: until == null ? l10n.pauseChooseUntil : formatPauseDate(until, locale),
      icon: Icons.event_rounded,
      variant: UmButtonVariant.secondary,
      expand: true,
      onPressed: _pickUntil,
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          UmSpace.s6,
          0,
          UmSpace.s6,
          UmSpace.s5 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.pauseSheetTitle, style: UmText.h2.copyWith(color: c.ink)),
            ),
            const SizedBox(height: UmSpace.s2),
            Text(l10n.pauseSheetBody, style: UmText.bodySm.copyWith(color: c.inkMuted)),
            const SizedBox(height: UmSpace.s4),
            Semantics(
              label: l10n.pauseModeLabel,
              child: SegmentedButton<PauseMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: PauseMode.dates, label: Text(l10n.pauseModeDates)),
                  ButtonSegment(value: PauseMode.days, label: Text(l10n.pauseModeDays)),
                  ButtonSegment(value: PauseMode.repeat, label: Text(l10n.pauseModeRepeat)),
                ],
                selected: {_mode},
                onSelectionChanged: (value) => setState(() => _mode = value.first),
              ),
            ),
            if (_mode == PauseMode.dates) ...[label(l10n.pauseDatesLabel), rangeButton],
            if (_mode == PauseMode.days) ...[
              label(l10n.pauseDaysLabel),
              Wrap(
                spacing: UmSpace.s2,
                runSpacing: UmSpace.s2,
                children: [
                  for (var day = 1; day <= 7; day++)
                    FilterChip(
                      label: Text(DateFormat.E(locale).format(DateTime(2024, 1, day))),
                      tooltip: DateFormat.EEEE(locale).format(DateTime(2024, 1, day)),
                      selected: _weekdays.contains(day),
                      onSelected: (on) =>
                          setState(() => on ? _weekdays.add(day) : _weekdays.remove(day)),
                    ),
                ],
              ),
              label(l10n.pauseUntilLabel),
              untilButton,
            ],
            if (_mode == PauseMode.repeat) ...[
              label(l10n.pauseFirstLabel),
              rangeButton,
              label(l10n.pauseFrequencyLabel),
              DropdownButtonFormField<PauseRepeat>(
                initialValue: _frequency,
                decoration: InputDecoration(labelText: l10n.pauseFrequencyLabel),
                items: [
                  for (final f in pauseFrequencies)
                    DropdownMenuItem(value: f, child: Text(_frequencyLabel(f, l10n))),
                ],
                onChanged: (value) => setState(() => _frequency = value ?? _frequency),
              ),
              label(l10n.pauseUntilLabel),
              untilButton,
            ],
            if (draft != null) ...[
              const SizedBox(height: UmSpace.s4),
              // Résumé de la pause, en une phrase.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.pause_circle_outline_rounded, color: c.brandStrong),
                  const SizedBox(width: UmSpace.s2),
                  Expanded(
                    child: Text(
                      describePause(
                        startsOn: draft.startsOn,
                        endsOn: draft.endsOn,
                        repeat: draft.repeat,
                        repeatUntil: draft.repeatUntil,
                        l10n: l10n,
                      ),
                      style: UmText.body.copyWith(color: c.ink, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
            if (tooLong) ...[
              const SizedBox(height: UmSpace.s3),
              UmErrorText(l10n.pauseTooLongForPeriod),
            ],
            if (_errorCode != null) ...[
              const SizedBox(height: UmSpace.s3),
              UmErrorText(apiErrorMessage(l10n, _errorCode)),
            ],
            const SizedBox(height: UmSpace.s4),
            UmButton(
              label: l10n.pauseSave,
              expand: true,
              loading: _busy,
              onPressed: draft == null || tooLong ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
