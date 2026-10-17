import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../data/chat_api.dart';
import 'chat_controller.dart';

/// Nouveau message : une personne (privé) ou plusieurs (groupe nommé), parmi celles croisées
/// sur un trajet. Renvoie l'identifiant de la conversation ouverte.
Future<String?> showNewConversationSheet(BuildContext context) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const NewConversationSheet(),
);

class NewConversationSheet extends ConsumerStatefulWidget {
  const NewConversationSheet({super.key});

  @override
  ConsumerState<NewConversationSheet> createState() => _NewConversationSheetState();
}

class _NewConversationSheetState extends ConsumerState<NewConversationSheet> {
  final Set<String> _picked = {};
  final _title = TextEditingController();
  bool _busy = false;
  String? _errorCode;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    try {
      final api = ref.read(chatApiProvider);
      final conversation = _picked.length == 1
          ? await api.createDirect(_picked.single)
          : await api.createGroup(_title.text.trim(), _picked.toList());
      ref.invalidate(conversationsProvider);
      if (mounted) Navigator.of(context).pop(conversation.id);
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
    final contacts = ref.watch(contactsProvider);
    final group = _picked.length > 1;
    final ready = _picked.isNotEmpty && (!group || _title.text.trim().isNotEmpty);

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
              child: Text(l10n.chatNew, style: UmText.h2.copyWith(color: c.ink)),
            ),
            const SizedBox(height: UmSpace.s2),
            Text(l10n.chatNewIntro, style: UmText.bodySm.copyWith(color: c.inkMuted)),
            const SizedBox(height: UmSpace.s3),
            switch (contacts) {
              AsyncValue(:final value?) when value.isEmpty => Text(
                l10n.chatNoContacts,
                style: UmText.body.copyWith(color: c.inkMuted),
              ),
              AsyncValue(:final value?) => Column(
                children: [
                  for (final contact in value)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _picked.contains(contact.userId),
                      title: Text(contact.firstName),
                      onChanged: (checked) => setState(
                        () => checked == true
                            ? _picked.add(contact.userId)
                            : _picked.remove(contact.userId),
                      ),
                    ),
                ],
              ),
              AsyncError(:final error) => UmErrorText(
                apiErrorMessage(l10n, error is ApiException ? error.code : null),
              ),
              _ => Semantics(
                label: l10n.loading,
                child: LinearProgressIndicator(color: c.brand),
              ),
            },
            if (group) ...[
              const SizedBox(height: UmSpace.s3),
              UmField(
                label: l10n.chatGroupName,
                controller: _title,
                maxLength: 60,
                onChanged: (_) => setState(() {}),
              ),
            ],
            if (_errorCode != null) ...[
              const SizedBox(height: UmSpace.s3),
              UmErrorText(apiErrorMessage(l10n, _errorCode)),
            ],
            const SizedBox(height: UmSpace.s4),
            UmButton(
              label: group ? l10n.chatCreateGroup : l10n.chatStart,
              expand: true,
              loading: _busy,
              onPressed: ready && !_busy ? _create : null,
            ),
          ],
        ),
      ),
    );
  }
}
