import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/um_theme.dart';

/// Calendrier compact : semaines entières (du lundi au dimanche) couvrant les jours
/// sélectionnables, en grandes cases (48 px au moins). Jours hors de la plage grisés.
class UmCalendar extends StatelessWidget {
  const UmCalendar({
    super.key,
    required this.first,
    required this.last,
    required this.selected,
    required this.onSelected,
  });

  final DateTime first;
  final DateTime last;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  static bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    final locale = Localizations.localeOf(context).toString();
    final start = DateTime(first.year, first.month, first.day - (first.weekday - 1));
    final end = DateTime(last.year, last.month, last.day + (7 - last.weekday));
    final days = [for (var d = start; !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) d];
    final firstDay = DateTime(first.year, first.month, first.day);
    final lastDay = DateTime(last.year, last.month, last.day);
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    DateFormat.E(locale).format(days[i]).substring(0, 1).toUpperCase(),
                    textAlign: TextAlign.center,
                    style: UmText.label.copyWith(color: c.inkMuted),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: UmSpace.s1),
        for (var w = 0; w < days.length ~/ 7; w++)
          Row(
            children: [
              for (final day in days.sublist(w * 7, w * 7 + 7))
                Expanded(
                  child: _Day(
                    day: day,
                    locale: locale,
                    enabled: !day.isBefore(firstDay) && !day.isAfter(lastDay),
                    selected: _same(day, selected),
                    onTap: () => onSelected(day),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({
    required this.day,
    this.locale = 'fr',
    this.enabled = false,
    this.selected = false,
    this.onTap,
  });

  final DateTime day;
  final String locale;
  final bool enabled;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    final color = selected ? c.onBrand : (enabled ? c.ink : c.inkMuted.withValues(alpha: 0.5));
    return Semantics(
      button: enabled,
      selected: selected,
      label: DateFormat('EEEE d MMMM', locale).format(day),
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: UmSize.tapTarget),
          child: Center(
            child: Container(
              width: UmSize.tapTarget - UmSpace.s2,
              height: UmSize.tapTarget - UmSpace.s2,
              alignment: Alignment.center,
              decoration: selected
                  ? BoxDecoration(color: c.brandStrong, shape: BoxShape.circle)
                  : null,
              child: Text(
                '${day.day}',
                style: UmText.body.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
