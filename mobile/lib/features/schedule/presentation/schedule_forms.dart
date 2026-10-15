import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/presentation/profile_forms.dart';
import '../domain/schedule.dart';
import 'schedule_controller.dart';

String weekdayName(AppLocalizations l10n, int weekday) => switch (weekday) {
  1 => l10n.weekday1,
  2 => l10n.weekday2,
  3 => l10n.weekday3,
  4 => l10n.weekday4,
  5 => l10n.weekday5,
  6 => l10n.weekday6,
  _ => l10n.weekday7,
};

/// Connexion d'un lien ICS avec consentement explicite (AGENTS.md, RGPD).
class IcsForm extends ConsumerStatefulWidget {
  const IcsForm({super.key, required this.frame});

  final ProfileFormFrame frame;

  @override
  ConsumerState<IcsForm> createState() => _IcsFormState();
}

class _IcsFormState extends ConsumerState<IcsForm> with SubmitStateMixin {
  final _url = TextEditingController();
  bool _consent = false;
  bool _showFieldErrors = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _showFieldErrors = true);
    if (_url.text.trim().length < 10 || !_consent) return;
    run(() async {
      await ref.read(scheduleProvider.notifier).connectIcs(_url.text);
      await widget.frame.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    return UmPage(
      appBar: widget.frame.appBar,
      overline: widget.frame.overline,
      title: l10n.icsTitle,
      intro: l10n.icsBody,
      footer: footerFor(widget.frame, l10n, _submit),
      children: [
        UmField(
          label: l10n.icsLabel,
          controller: _url,
          placeholder: l10n.icsPlaceholder,
          keyboardType: TextInputType.url,
          error: _showFieldErrors && _url.text.trim().length < 10 ? l10n.errorCalendarUrl : null,
        ),
        const SizedBox(height: UmSpace.s4),
        CheckboxListTile(
          value: _consent,
          onChanged: (value) => setState(() => _consent = value ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(l10n.icsConsent, style: UmText.bodySm.copyWith(color: c.ink)),
        ),
        if (_showFieldErrors && !_consent) ...[
          const SizedBox(height: UmSpace.s2),
          UmErrorText(l10n.icsConsentRequired),
        ],
        ...errorFor(l10n),
      ],
    );
  }
}

/// Semaine type saisie à la main (secours sans agenda).
class ManualScheduleForm extends ConsumerStatefulWidget {
  const ManualScheduleForm({super.key, required this.initial, required this.frame});

  final List<ManualDay> initial;
  final ProfileFormFrame frame;

  @override
  ConsumerState<ManualScheduleForm> createState() => _ManualScheduleFormState();
}

class _ManualScheduleFormState extends ConsumerState<ManualScheduleForm> with SubmitStateMixin {
  /// Jour ISO → horaires ; absent = pas de cours. Par défaut : lundi à vendredi, 8 h - 17 h.
  late final Map<int, ManualDay> _days = {
    for (final d
        in widget.initial.isEmpty
            ? [
                for (var w = 1; w <= 5; w++)
                  ManualDay(weekday: w, startTime: '08:00', endTime: '17:00'),
              ]
            : widget.initial)
      d.weekday: d,
  };
  bool _showFieldErrors = false;

  Future<void> _pick(int weekday, {required bool start}) async {
    final day = _days[weekday]!;
    final current = (start ? day.startTime : day.endTime).split(':').map(int.parse).toList();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current[0], minute: current[1]),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    final value = ManualDay.format(picked.hour, picked.minute);
    setState(
      () => _days[weekday] = ManualDay(
        weekday: weekday,
        startTime: start ? value : day.startTime,
        endTime: start ? day.endTime : value,
      ),
    );
  }

  void _submit() {
    setState(() => _showFieldErrors = true);
    if (_days.values.any((d) => !d.isValid)) return;
    run(() async {
      final days = _days.values.toList()..sort((a, b) => a.weekday.compareTo(b.weekday));
      await ref.read(scheduleProvider.notifier).setManual(days);
      await widget.frame.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    return UmPage(
      appBar: widget.frame.appBar,
      overline: widget.frame.overline,
      title: l10n.manualTitle,
      intro: l10n.manualBody,
      footer: footerFor(widget.frame, l10n, _submit),
      children: [
        for (var weekday = 1; weekday <= 7; weekday++) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _days.containsKey(weekday),
            title: Text(weekdayName(l10n, weekday), style: UmText.label.copyWith(color: c.ink)),
            subtitle: _days.containsKey(weekday) ? null : Text(l10n.manualDayOff),
            onChanged: (on) => setState(() {
              if (on) {
                _days[weekday] = ManualDay(weekday: weekday, startTime: '08:00', endTime: '17:00');
              } else {
                _days.remove(weekday);
              }
            }),
          ),
          if (_days[weekday] case final day?)
            Padding(
              padding: const EdgeInsets.only(bottom: UmSpace.s3),
              child: Wrap(
                spacing: UmSpace.s3,
                runSpacing: UmSpace.s2,
                children: [
                  for (final start in [true, false])
                    Semantics(
                      label: l10n.manualTimeLabel(
                        weekdayName(l10n, weekday),
                        start ? l10n.manualStart : l10n.manualEnd,
                        start ? day.startTime : day.endTime,
                      ),
                      excludeSemantics: true,
                      child: UmButton(
                        label:
                            '${start ? l10n.manualStart : l10n.manualEnd} ${start ? day.startTime : day.endTime}',
                        icon: Icons.schedule_rounded,
                        variant: UmButtonVariant.secondary,
                        onPressed: () => _pick(weekday, start: start),
                      ),
                    ),
                  if (_showFieldErrors && !day.isValid) UmErrorText(l10n.manualInvalid),
                ],
              ),
            ),
        ],
        ...errorFor(l10n),
      ],
    );
  }
}
