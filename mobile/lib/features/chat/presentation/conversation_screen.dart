import 'dart:typed_data';

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
import '../../proposals/domain/proposal.dart';
import '../../rides/presentation/trip_widgets.dart';
import '../../profile/presentation/me_controller.dart';
import '../domain/chat.dart';
import '../../profile/presentation/person_avatar.dart';
import 'carpool_widgets.dart';
import 'message_bubble.dart';
import 'chat_controller.dart';
import 'chat_labels.dart';
import 'conversations_screen.dart';

/// Conversation : messages en direct, envoi ; chat de trajet archivé en lecture seule (§6).
class ConversationScreen extends ConsumerWidget {
  const ConversationScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final state = ref.watch(conversationProvider(id));
    return switch (state) {
      AsyncError(:final error) when !state.hasValue => UmPage(
        appBar: AppBar(),
        children: [
          UmErrorText(apiErrorMessage(l10n, error is ApiException ? error.code : null)),
          UmButton(
            label: l10n.retry,
            variant: UmButtonVariant.ghost,
            onPressed: () => ref.invalidate(conversationProvider(id)),
          ),
        ],
      ),
      AsyncValue(:final value?) => _Conversation(state: value),
      _ => UmPage(
        appBar: AppBar(),
        children: [
          Semantics(
            label: l10n.loading,
            child: LinearProgressIndicator(color: c.brand),
          ),
        ],
      ),
    };
  }
}

class _Conversation extends ConsumerStatefulWidget {
  const _Conversation({required this.state});

  final ConversationState state;

  @override
  ConsumerState<_Conversation> createState() => _ConversationState();
}

class _ConversationState extends ConsumerState<_Conversation> {
  final _text = TextEditingController();
  bool _sending = false;
  String? _errorCode;

  @override
  void initState() {
    super.initState();
    // Le bouton d'envoi suit le texte : désactivé quand il n'y a rien à envoyer.
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String get _id => widget.state.conversation.id;

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty) return;
    setState(() {
      _sending = true;
      _errorCode = null;
    });
    try {
      await ref.read(conversationProvider(_id).notifier).send(body);
      _text.clear();
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorCode = error.code);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _react(String messageId, String me, String? emoji) async {
    setState(() => _errorCode = null);
    try {
      await ref.read(conversationProvider(_id).notifier).react(messageId, me, emoji);
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorCode = error.code);
    }
  }

  /// « + » : photo de la galerie, photo prise sur le moment, ou trajet (groupe et privé).
  Future<void> _attach(Conversation conversation) async {
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.photoFromGallery),
              onTap: () => Navigator.of(sheet).pop('gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.photoFromCamera),
              onTap: () => Navigator.of(sheet).pop('camera'),
            ),
            // Groupe ou privé : proposer un trajet ou en chercher un, accepté d'un toucher.
            if (conversation.kind != ConversationKind.ride)
              ListTile(
                leading: const Icon(Icons.directions_car_outlined),
                title: Text(l10n.carpoolTitle),
                onTap: () => Navigator.of(sheet).pop('carpool'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'carpool') {
      await showCarpoolSheet(context, conversation.id);
      return;
    }
    Uint8List? bytes;
    try {
      bytes = await ref.read(photoPickerProvider)(camera: choice == 'camera', large: true);
    } on Object {
      if (mounted) setState(() => _errorCode = 'photo_unavailable');
      return;
    }
    if (bytes == null || !mounted) return;
    // Le texte en cours devient la légende de la photo.
    final caption = _text.text.trim();
    setState(() {
      _sending = true;
      _errorCode = null;
    });
    try {
      await ref
          .read(conversationProvider(_id).notifier)
          .sendPhoto(bytes, imageContentType(bytes), caption: caption);
      _text.clear();
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorCode = error.code);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _loadOlder() async {
    setState(() => _errorCode = null);
    try {
      await ref.read(conversationProvider(_id).notifier).loadOlder();
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorCode = error.code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final me = ref.watch(meProvider.select((m) => m.value?.id));
    final now = ref.watch(clockProvider)();
    final conversation = widget.state.conversation;
    final messages = widget.state.messages;
    final showSender = conversation.kind != ConversationKind.direct;
    ChatMember? memberOf(String userId) =>
        conversation.members.where((m) => m.userId == userId).firstOrNull;
    String nameOf(String userId) => memberOf(userId)?.firstName ?? l10n.chatFormerMember;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        // Toucher l'en-tête, comme dans une messagerie : infos du groupe (ou du trajet), ou le
        // profil de la personne en privé.
        title: Semantics(
          button: true,
          hint: conversation.kind == ConversationKind.direct
              ? l10n.chatDirectInfo
              : (conversation.kind == ConversationKind.group
                    ? l10n.chatGroupInfo
                    : l10n.chatRideInfo),
          child: InkWell(
            borderRadius: BorderRadius.circular(UmRadius.sm),
            onTap: () {
              final person = conversation.kind == ConversationKind.direct
                  ? conversation.others(me).firstOrNull
                  : null;
              context.push(
                person != null
                    ? AppRoutes.person(person.userId)
                    : AppRoutes.conversationInfo(conversation.id),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: UmSpace.s1),
              child: Row(
                children: [
                  ConversationAvatar(conversation: conversation, me: me),
                  const SizedBox(width: UmSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            conversationTitle(l10n, conversation, me),
                            style: UmText.h3.copyWith(color: c.ink),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          conversationMembers(l10n, conversation, me),
                          style: UmText.bodySm.copyWith(color: c.inkMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Chat de trajet : le trajet est à un toucher, épinglé en haut de la conversation.
            if (conversation.rideId case final rideId?)
              _RideBar(
                label: conversation.rideDay == null
                    ? l10n.chatRideBar
                    : tripTitle(
                        l10n,
                        conversation.rideToCampus ?? true
                            ? Direction.toCampus
                            : Direction.fromCampus,
                        conversation.rideDay!,
                      ),
                onTap: () => context.push(AppRoutes.ride(rideId)),
              ),
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(UmSpace.s6),
                        child: Text(
                          l10n.chatNoMessages,
                          textAlign: TextAlign.center,
                          style: UmText.body.copyWith(color: c.inkMuted),
                        ),
                      ),
                    )
                  : ListView.builder(
                      // Les plus récents en bas, visibles à l'ouverture.
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: UmSpace.s3,
                        vertical: UmSpace.s3,
                      ),
                      itemCount: messages.length + (widget.state.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == messages.length) {
                          return Center(
                            child: UmButton(
                              label: l10n.chatOlder,
                              variant: UmButtonVariant.ghost,
                              onPressed: _loadOlder,
                            ),
                          );
                        }
                        final position = messages.length - 1 - index;
                        final message = messages[position];
                        final mine = message.senderId == me;
                        // Série : messages consécutifs du même auteur, le même jour. Prénom en
                        // tête de série, photo à côté du dernier message (comme une messagerie).
                        bool sameRun(ChatMessage? other) =>
                            other != null &&
                            other.senderId == message.senderId &&
                            other.carpool == null &&
                            sameDay(other.createdAt, message.createdAt);
                        final previous = position > 0 ? messages[position - 1] : null;
                        final next = position < messages.length - 1 ? messages[position + 1] : null;
                        final firstOfRun = !sameRun(previous);
                        final lastOfRun = !sameRun(next);
                        final author = memberOf(message.senderId);
                        final sender = showSender && !mine && firstOfRun
                            ? (author?.firstName ?? l10n.chatFormerMember)
                            : null;
                        final Widget bubble = message.carpool != null
                            ? CarpoolCard(
                                message: message,
                                mine: mine,
                                myId: me,
                                sender: showSender && !mine ? nameOf(message.senderId) : null,
                              )
                            : MessageBubble(
                                message: message,
                                mine: mine,
                                myId: me,
                                sender: sender,
                                senderColor: context.umPersonColor(message.senderId),
                                avatarSlot: showSender,
                                avatar: showSender && !mine && lastOfRun
                                    ? GestureDetector(
                                        onTap: () =>
                                            context.push(AppRoutes.person(message.senderId)),
                                        child: PersonAvatar(
                                          name: author?.firstName ?? '?',
                                          photoUrl: author?.photoUrl,
                                        ),
                                      )
                                    : null,
                                onReact: conversation.archived || me == null
                                    ? null
                                    : (emoji) => _react(message.id, me, emoji),
                                onOpenPhoto: (url) => showChatPhoto(context, url),
                              );
                        // Liste inversée : le séparateur de jour vient au-dessus du premier message du jour.
                        final firstOfDay =
                            position == 0 ||
                            !sameDay(messages[position - 1].createdAt, message.createdAt);
                        if (!firstOfDay) return bubble;
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: UmSpace.s2),
                              child: Text(
                                formatMessageDay(l10n, message.createdAt, now),
                                style: UmText.caption.copyWith(color: c.inkMuted),
                              ),
                            ),
                            bubble,
                          ],
                        );
                      },
                    ),
            ),
            if (_errorCode != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: UmSpace.s6),
                child: UmErrorText(apiErrorMessage(l10n, _errorCode)),
              ),
            if (conversation.archived)
              Container(
                padding: const EdgeInsets.all(UmSpace.s4),
                color: c.surfaceTint,
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: UmSize.iconMd, color: c.brandStrong),
                    const SizedBox(width: UmSpace.s2),
                    Expanded(
                      child: Text(l10n.chatArchivedBody, style: UmText.body.copyWith(color: c.ink)),
                    ),
                  ],
                ),
              )
            else
              // Saisie compacte : « + » (photo, appareil, trajet), champ arrondi, envoi.
              Padding(
                padding: const EdgeInsets.fromLTRB(UmSpace.s1, UmSpace.s2, UmSpace.s1, UmSpace.s3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: l10n.chatAttach,
                      constraints: const BoxConstraints(
                        minWidth: UmSize.tapTarget,
                        minHeight: UmSize.tapTarget,
                      ),
                      icon: Icon(Icons.add_rounded, color: c.brandStrong),
                      onPressed: _sending ? null : () => _attach(conversation),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _text,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 2000,
                        textCapitalization: TextCapitalization.sentences,
                        style: UmText.body.copyWith(color: c.ink),
                        decoration: InputDecoration(
                          hintText: l10n.chatMessageLabel,
                          hintStyle: UmText.body.copyWith(color: c.inkMuted),
                          counterText: '',
                          isDense: true,
                          filled: true,
                          fillColor: c.surfaceRaised,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: UmSpace.s4,
                            vertical: UmSpace.s3,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(UmRadius.lg),
                            borderSide: BorderSide(color: c.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(UmRadius.lg),
                            borderSide: BorderSide(color: c.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(UmRadius.lg),
                            borderSide: BorderSide(color: c.focus, width: UmSize.controlBorder),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.chatSend,
                      constraints: const BoxConstraints(
                        minWidth: UmSize.tapTarget,
                        minHeight: UmSize.tapTarget,
                      ),
                      icon: _sending
                          ? SizedBox.square(
                              dimension: UmSize.iconMd,
                              child: CircularProgressIndicator(
                                strokeWidth: UmSize.iconStroke,
                                color: c.brandStrong,
                              ),
                            )
                          : Icon(
                              Icons.send_rounded,
                              color: _text.text.trim().isEmpty ? c.inkMuted : c.brandStrong,
                            ),
                      onPressed: _sending || _text.text.trim().isEmpty ? null : _send,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bandeau du trajet en haut d'un chat de trajet : ouvre la carte et les détails.
class _RideBar extends StatelessWidget {
  const _RideBar({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    return Material(
      color: c.lavender,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          button: true,
          label: '$label. ${l10n.chatSeeRide}',
          excludeSemantics: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: UmSize.tapTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: UmSpace.s5, vertical: UmSpace.s2),
              child: Row(
                children: [
                  Icon(Icons.directions_car_rounded, color: c.brandStrong),
                  const SizedBox(width: UmSpace.s3),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: UmText.body.copyWith(
                        color: c.brandStrong,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(l10n.chatSeeRide, style: UmText.button.copyWith(color: c.brandStrong)),
                  Icon(Icons.chevron_right_rounded, color: c.brandStrong),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
