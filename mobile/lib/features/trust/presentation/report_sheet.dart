import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../data/trust_api.dart';
import '../domain/trust.dart';

/// Signaler une personne croisée sur ce trajet ; renvoie `true` une fois envoyé.
Future<bool> showReportSheet(
  BuildContext context,
  List<({String userId, String name})> people,
) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ReportSheet(people: people),
    ) ??
    false;

class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({super.key, required this.people});

  final List<({String userId, String name})> people;

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  late String? _who = widget.people.length == 1 ? widget.people.single.userId : null;
  ReportReason? _why;
  final _message = TextEditingController();
  bool _busy = false;
  String? _errorCode;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final who = _who;
    final why = _why;
    if (who == null || why == null) return;
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    try {
      final text = _message.text.trim();
      await ref.read(trustApiProvider).report(who, why, text.isEmpty ? null : text);
      if (mounted) Navigator.of(context).pop(true);
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
    String label(ReportReason r) => switch (r) {
      ReportReason.dangerousDriving => l10n.reportDangerous,
      ReportReason.inappropriateBehaviour => l10n.reportInappropriate,
      ReportReason.fakeProfile => l10n.reportFake,
      ReportReason.other => l10n.reportOther,
    };

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
              child: Text(l10n.reportAction, style: UmText.h2.copyWith(color: c.ink)),
            ),
            const SizedBox(height: UmSpace.s2),
            Text(l10n.reportIntro, style: UmText.bodySm.copyWith(color: c.inkMuted)),
            const SizedBox(height: UmSpace.s2),
            Text(
              l10n.reportEmergency,
              style: UmText.bodySm.copyWith(color: c.ink, fontWeight: FontWeight.w600),
            ),
            if (widget.people.length > 1) ...[
              const SizedBox(height: UmSpace.s4),
              Text(l10n.reportWho, style: UmText.label.copyWith(color: c.brandStrong)),
              RadioGroup<String>(
                groupValue: _who,
                onChanged: (value) => setState(() => _who = value),
                child: Column(
                  children: [
                    for (final p in widget.people)
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: p.userId,
                        title: Text(p.name),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: UmSpace.s4),
            Text(l10n.reportWhy, style: UmText.label.copyWith(color: c.brandStrong)),
            RadioGroup<ReportReason>(
              groupValue: _why,
              onChanged: (value) => setState(() => _why = value),
              child: Column(
                children: [
                  for (final r in ReportReason.values)
                    RadioListTile<ReportReason>(
                      contentPadding: EdgeInsets.zero,
                      value: r,
                      title: Text(label(r)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: UmSpace.s3),
            UmField(
              label: l10n.disputeMessageLabel,
              controller: _message,
              maxLines: 4,
              maxLength: 1000,
            ),
            if (_errorCode != null) ...[
              const SizedBox(height: UmSpace.s3),
              UmErrorText(apiErrorMessage(l10n, _errorCode)),
            ],
            const SizedBox(height: UmSpace.s4),
            UmButton(
              label: l10n.reportSend,
              expand: true,
              loading: _busy,
              onPressed: _who == null || _why == null || _busy ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}
