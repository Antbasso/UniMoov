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
import '../../profile/presentation/me_controller.dart';
import '../domain/chat.dart';
import '../../profile/presentation/person_avatar.dart';
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
          // Trois sections bien séparées : privé, groupes, chats de trajet (éphémères).
          AsyncValue(:final value?) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (kind, title, note) in [
                (ConversationKind.direct, l10n.chatSectionDirect, null),
                (ConversationKind.group, l10n.chatSectionGroups, null),
                (ConversationKind.ride, l10n.chatSectionRides, l10n.chatSectionRidesNote),
              ])
                if (value.where((c) => c.kind == kind).toList() case final list
                    when list.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: UmSpace.s3, bottom: UmSpace.s1),
                    child: UmSectionTitle(title),
                  ),
                  if (note != null) Text(note, style: UmText.caption.copyWith(color: c.inkMuted)),
                  for (final conversation in list)
                    _ConversationRow(conversation: conversation, me: me),
                ],
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

/// Une conversation sur une ligne, comme une messagerie : photo, nom et heure, aperçu et
/// pastille de non-lus à droite. Toujours deux lignes d'une ligne chacune : toutes les cellules
/// ont la même hauteur, le texte trop long se termine par « … ».
class _ConversationRow extends ConsumerWidget {
  const _ConversationRow({required this.conversation, required this.me});

  final Conversation conversation;
  final String? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final now = ref.watch(clockProvider)();
    final unread = conversation.unread > 0;
    final last = conversation.lastMessage;
    final title = conversationTitle(l10n, conversation, me);
    // Photo sans légende : « Photo » plutôt qu'un aperçu vide.
    final lastText = last == null
        ? null
        : last.photoUrl != null && last.body.isEmpty
        ? l10n.chatLastPhoto
        : last.body;
    final preview = last == null
        ? conversationMembers(l10n, conversation, me)
        : (last.senderId == me ? l10n.chatYouSaid(lastText!) : lastText!);
    final leading = ConversationAvatar(conversation: conversation, me: me);
    return Semantics(
      button: true,
      label: [
        title,
        if (unread) l10n.chatUnread(conversation.unread),
        if (conversation.archived) l10n.chatArchived,
        preview,
      ].join('. '),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(UmRadius.sm),
        // Chargement lancé dès que le doigt se pose, avant l'ouverture.
        onTapDown: (_) => ref.read(conversationProvider(conversation.id)),
        onTap: () => context.push(AppRoutes.conversation(conversation.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: UmSpace.s2),
          child: Row(
            children: [
              leading,
              const SizedBox(width: UmSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: UmText.body.copyWith(
                              color: c.ink,
                              fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (last != null) ...[
                          const SizedBox(width: UmSpace.s2),
                          Text(
                            formatMessageWhen(l10n, last.createdAt, now),
                            style: UmText.caption.copyWith(
                              color: unread ? c.brandStrong : c.inkMuted,
                              fontWeight: unread ? FontWeight.w700 : null,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: UmSpace.s1),
                    Row(
                      children: [
                        if (conversation.archived) ...[
                          Icon(Icons.inventory_2_outlined, size: UmSize.iconSm, color: c.inkMuted),
                          const SizedBox(width: UmSpace.s1),
                        ],
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: UmText.bodySm.copyWith(color: unread ? c.ink : c.inkMuted),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: UmSpace.s2),
                          // Pastille à droite, sous l'heure, dans la même hauteur de ligne.
                          Container(
                            constraints: const BoxConstraints(minWidth: UmSpace.s5),
                            padding: const EdgeInsets.symmetric(horizontal: UmSpace.s2),
                            decoration: BoxDecoration(
                              color: c.brand,
                              borderRadius: BorderRadius.circular(UmRadius.pill),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              conversation.unread > 99 ? '99+' : '${conversation.unread}',
                              style: UmText.caption.copyWith(
                                color: c.onBrand,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Photo d'une conversation : celle de l'autre personne en privé, une icône pour un groupe ou
/// un trajet.
class ConversationAvatar extends StatelessWidget {
  const ConversationAvatar({super.key, required this.conversation, required this.me});

  final Conversation conversation;
  final String? me;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    final other = conversation.kind == ConversationKind.direct
        ? conversation.others(me).firstOrNull
        : null;
    if (other != null) return PersonAvatar(name: other.firstName, photoUrl: other.photoUrl);
    return CircleAvatar(
      radius: UmSize.avatar / 2,
      backgroundColor: c.lavender,
      child: Icon(
        conversation.kind == ConversationKind.ride
            ? Icons.directions_car_rounded
            : Icons.groups_rounded,
        color: c.brandStrong,
      ),
    );
  }
}
