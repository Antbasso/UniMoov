import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/presentation/me_controller.dart';
import '../../profile/presentation/person_avatar.dart';
import '../domain/chat.dart';
import 'chat_controller.dart';
import 'chat_labels.dart';
import 'conversations_screen.dart';

/// Infos d'une conversation de groupe ou de trajet, comme dans une messagerie : nom (que l'on
/// peut changer), membres (toucher pour voir le profil), ajouter des personnes croisées,
/// retirer quelqu'un (créateur du groupe), quitter le groupe.
class ConversationInfoScreen extends ConsumerStatefulWidget {
  const ConversationInfoScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ConversationInfoScreen> createState() => _ConversationInfoScreenState();
}

class _ConversationInfoScreenState extends ConsumerState<ConversationInfoScreen> {
  bool _busy = false;
  String? _errorCode;

  ConversationController get _controller => ref.read(conversationProvider(widget.id).notifier);

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    try {
      await action();
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorCode = error.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename(Conversation conversation) async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: conversation.title ?? ''),
    );
    if (title == null || title.isEmpty || title == conversation.title) return;
    await _run(() => _controller.rename(title));
  }

  Future<void> _add(Conversation conversation) async {
    final l10n = AppLocalizations.of(context);
    final inGroup = {for (final m in conversation.members) m.userId};
    final contacts = await ref.read(contactsProvider.future);
    final candidates = contacts.where((m) => !inGroup.contains(m.userId)).toList();
    if (!mounted) return;
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => _AddMembersSheet(candidates: candidates, empty: l10n.chatGroupAddNone),
    );
    if (picked == null || picked.isEmpty) return;
    await _run(() => _controller.addMembers(picked));
  }

  Future<void> _leave() async {
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.chatLeaveTitle),
        content: Text(l10n.chatLeaveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.chatLeaveCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l10n.chatLeaveConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      await _controller.leave();
      router.go(AppRoutes.messages);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final me = ref.watch(meProvider.select((m) => m.value?.id));
    final state = ref.watch(conversationProvider(widget.id));
    final conversation = state.value?.conversation;
    if (conversation == null) {
      return UmPage(
        appBar: AppBar(),
        children: [
          if (state.hasError)
            UmErrorText(apiErrorMessage(l10n, null))
          else
            Semantics(label: l10n.loading, child: const LinearProgressIndicator()),
        ],
      );
    }
    final group = conversation.kind == ConversationKind.group;
    final creator = group && conversation.createdBy == me;
    final members = [...conversation.members]
      ..sort(
        (a, b) => a.userId == me ? -1 : (b.userId == me ? 1 : a.firstName.compareTo(b.firstName)),
      );

    return UmPage(
      appBar: AppBar(title: Text(group ? l10n.chatGroupInfo : l10n.chatRideInfo)),
      children: [
        Center(
          child: Transform.scale(
            scale: UmSize.avatarXl / UmSize.avatar,
            child: ConversationAvatar(conversation: conversation, me: me),
          ),
        ),
        const SizedBox(height: UmSpace.s7),
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  conversationTitle(l10n, conversation, me),
                  textAlign: TextAlign.center,
                  style: UmText.h2.copyWith(color: c.ink),
                ),
              ),
            ),
            if (group && !conversation.archived)
              IconButton(
                tooltip: l10n.chatGroupRename,
                icon: Icon(Icons.edit_outlined, color: c.brandStrong),
                onPressed: _busy ? null : () => _rename(conversation),
              ),
          ],
        ),
        Text(
          l10n.chatGroupMembers(conversation.members.length),
          textAlign: TextAlign.center,
          style: UmText.body.copyWith(color: c.inkMuted),
        ),
        if (conversation.rideId case final rideId?) ...[
          const SizedBox(height: UmSpace.s4),
          UmButton(
            label: l10n.chatSeeRide,
            icon: Icons.directions_car_outlined,
            variant: UmButtonVariant.secondary,
            expand: true,
            onPressed: () => context.push(AppRoutes.ride(rideId)),
          ),
        ],
        const SizedBox(height: UmSpace.s5),
        UmSectionTitle(l10n.chatGroupMembers(conversation.members.length)),
        const SizedBox(height: UmSpace.s2),
        if (group && !conversation.archived)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: UmSize.avatar / 2,
              backgroundColor: c.brand,
              child: Icon(Icons.person_add_alt_rounded, color: c.onBrand),
            ),
            title: Text(
              l10n.chatGroupAdd,
              style: UmText.body.copyWith(color: c.brandStrong, fontWeight: FontWeight.w600),
            ),
            onTap: _busy ? null : () => _add(conversation),
          ),
        for (final member in members)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: PersonAvatar(name: member.firstName, photoUrl: member.photoUrl),
            title: Text(
              member.userId == me ? l10n.chatGroupYou : member.firstName,
              style: UmText.body.copyWith(
                color: context.umPersonColor(member.userId),
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: conversation.createdBy == member.userId && group
                ? Text(l10n.chatGroupCreator, style: UmText.caption.copyWith(color: c.inkMuted))
                : null,
            onTap: member.userId == me ? null : () => context.push(AppRoutes.person(member.userId)),
            trailing: creator && member.userId != me && !conversation.archived
                ? IconButton(
                    tooltip: l10n.chatGroupRemove(member.firstName),
                    icon: Icon(Icons.person_remove_outlined, color: c.danger),
                    onPressed: _busy
                        ? null
                        : () => _run(() => _controller.removeMember(member.userId)),
                  )
                : (member.userId == me
                      ? null
                      : Icon(Icons.chevron_right_rounded, color: c.inkMuted)),
          ),
        if (_errorCode != null) ...[
          const SizedBox(height: UmSpace.s3),
          UmErrorText(apiErrorMessage(l10n, _errorCode)),
        ],
        if (group) ...[
          const SizedBox(height: UmSpace.s5),
          UmButton(
            label: l10n.chatLeave,
            icon: Icons.logout_rounded,
            variant: UmButtonVariant.ghost,
            expand: true,
            onPressed: _busy ? null : _leave,
          ),
        ],
      ],
    );
  }
}

/// Nouveau nom du groupe ; le champ vit avec la boîte de dialogue (fermeture animée comprise).
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _field = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.chatGroupRename),
      content: TextField(
        controller: _field,
        autofocus: true,
        maxLength: 60,
        decoration: InputDecoration(labelText: l10n.chatGroupRename),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.chatLeaveCancel)),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_field.text.trim()),
          child: Text(l10n.chatGroupRenameAction),
        ),
      ],
    );
  }
}

class _AddMembersSheet extends StatefulWidget {
  const _AddMembersSheet({required this.candidates, required this.empty});

  final List<ChatMember> candidates;
  final String empty;

  @override
  State<_AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends State<_AddMembersSheet> {
  final _picked = <String>{};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(UmSpace.s5, 0, UmSpace.s5, UmSpace.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UmSectionTitle(l10n.chatGroupAdd),
            const SizedBox(height: UmSpace.s2),
            if (widget.candidates.isEmpty)
              Text(widget.empty, style: UmText.body.copyWith(color: c.inkMuted))
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final m in widget.candidates)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _picked.contains(m.userId),
                        onChanged: (on) => setState(
                          () => on == true ? _picked.add(m.userId) : _picked.remove(m.userId),
                        ),
                        secondary: PersonAvatar(name: m.firstName, photoUrl: m.photoUrl),
                        title: Text(m.firstName),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: UmSpace.s3),
            UmButton(
              label: l10n.chatGroupAdd,
              expand: true,
              onPressed: _picked.isEmpty ? null : () => Navigator.of(context).pop(_picked.toList()),
            ),
          ],
        ),
      ),
    );
  }
}
