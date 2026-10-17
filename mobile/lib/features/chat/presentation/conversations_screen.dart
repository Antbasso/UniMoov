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
import '../../proposals/presentation/formatting.dart';
import '../domain/chat.dart';
import 'chat_controller.dart';
import 'chat_labels.dart';
import 'new_conversation_sheet.dart';

/// Messages (cahier §6) : mes conversations, la plus récente d'abord, avec les non lus.
class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final conversations = ref.watch(conversationsProvider);
    final me = ref.watch(meProvider.select((m) => m.value?.id));

    Future<void> start() async {
      final id = await showNewConversationSheet(context);
      if (id != null && context.mounted) await context.push(AppRoutes.conversation(id));
    }

    return UmPage(
      appBar: AppBar(),
      title: l10n.chatTitle,
      footer: [
        UmButton(label: l10n.chatNew, icon: Icons.edit_outlined, expand: true, onPressed: start),
      ],
      children: [
        switch (conversations) {
          AsyncError(:final error) when !conversations.hasValue => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UmErrorText(apiErrorMessage(l10n, error is ApiException ? error.code : null)),
              UmButton(
                label: l10n.retry,
                variant: UmButtonVariant.ghost,
                onPressed: () => ref.invalidate(conversationsProvider),
              ),
            ],
          ),
          AsyncValue(:final value?) when value.isEmpty => Text(
            l10n.chatEmpty,
            style: UmText.body.copyWith(color: c.inkMuted),
          ),
          AsyncValue(:final value?) => Column(
            children: [
              for (final conversation in value)
                _ConversationRow(conversation: conversation, me: me),
            ],
          ),
          _ => Semantics(
            label: l10n.loading,
            child: LinearProgressIndicator(color: c.brand),
          ),
        },
      ],
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conversation, required this.me});

  final Conversation conversation;
  final String? me;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final last = conversation.lastMessage;
    final title = conversationTitle(l10n, conversation, me);
    final preview = last == null
        ? conversationMembers(l10n, conversation, me)
        : (last.senderId == me ? l10n.chatYouSaid(last.body) : last.body);
    return Padding(
      padding: const EdgeInsets.only(bottom: UmSpace.s3),
      child: Semantics(
        button: true,
        label: [
          title,
          if (conversation.unread > 0) l10n.chatUnread(conversation.unread),
          if (conversation.archived) l10n.chatArchived,
          preview,
        ].join('. '),
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(UmRadius.lg),
          onTap: () => context.push(AppRoutes.conversation(conversation.id)),
          child: UmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      switch (conversation.kind) {
                        ConversationKind.ride => Icons.directions_car_outlined,
                        ConversationKind.group => Icons.groups_outlined,
                        ConversationKind.direct => Icons.person_outline_rounded,
                      },
                      size: UmSize.iconMd,
                      color: c.brandStrong,
                    ),
                    const SizedBox(width: UmSpace.s2),
                    Expanded(
                      child: Text(
                        title,
                        style: UmText.body.copyWith(color: c.ink, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (last != null)
                      Text(
                        formatTime(last.createdAt, l10n.localeName),
                        style: UmText.caption.copyWith(color: c.inkMuted),
                      ),
                  ],
                ),
                const SizedBox(height: UmSpace.s1),
                Text(
                  preview,
                  style: UmText.bodySm.copyWith(color: c.inkMuted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (conversation.unread > 0 || conversation.archived) ...[
                  const SizedBox(height: UmSpace.s2),
                  Wrap(
                    spacing: UmSpace.s2,
                    children: [
                      if (conversation.unread > 0)
                        UmChip(
                          label: l10n.chatUnread(conversation.unread),
                          icon: Icons.mark_chat_unread_outlined,
                          tone: UmChipTone.success,
                        ),
                      if (conversation.archived)
                        UmChip(label: l10n.chatArchived, icon: Icons.inventory_2_outlined),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
