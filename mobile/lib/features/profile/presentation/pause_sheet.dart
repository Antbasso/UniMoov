import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import 'me_controller.dart';

Future<void> showPauseSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const PauseSheet(),
);

String formatPauseDate(DateTime date, String locale) => DateFormat.yMMMd(locale).format(date);

/// Programmer une pause (cahier §12) : dates, et option une semaine sur deux.
class PauseSheet extends ConsumerStatefulWidget {
  const PauseSheet({super.key});

  @override
  ConsumerState<PauseSheet> createState() => _PauseSheetState();
}

class _PauseSheetState extends ConsumerState<PauseSheet> {
  DateTimeRange? _range;
  bool _alternating = false;
  bool _busy = false;
  String? _errorCode;

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, now.month, now.day),
      initialDateRange: _range,
    );
    if (range != null) setState(() => _range = range);
  }

  Future<void> _save() async {
    final range = _range;
    if (range == null) return;
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    try {
      await ref.read(pausesProvider.notifier).add(range.start, range.end, _alternating ? 2 : null);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorCode = error.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final range = _range;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(UmSpace.s6, 0, UmSpace.s6, UmSpace.s5),
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
            const SizedBox(height: UmSpace.s5),
            UmButton(
              label: range == null
                  ? l10n.pauseChooseDates
                  : l10n.pauseRange(
                      formatPauseDate(range.start, l10n.localeName),
                      formatPauseDate(range.end, l10n.localeName),
                    ),
              icon: Icons.date_range_rounded,
              variant: UmButtonVariant.secondary,
              expand: true,
              onPressed: _pickDates,
            ),
            const SizedBox(height: UmSpace.s3),
            SwitchListTile(
              value: _alternating,
              onChanged: (value) => setState(() => _alternating = value),
              title: Text(l10n.pauseAlternatingToggle),
            ),
            if (_errorCode != null) ...[
              const SizedBox(height: UmSpace.s3),
              UmErrorText(apiErrorMessage(l10n, _errorCode)),
            ],
            const SizedBox(height: UmSpace.s4),
            UmButton(
              label: l10n.pauseSave,
              expand: true,
              loading: _busy,
              onPressed: range == null ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
