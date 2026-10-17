import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/presentation/me_controller.dart';
import '../../proposals/presentation/formatting.dart';
import '../domain/chat.dart';
import 'chat_controller.dart';
import 'chat_labels.dart';

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

  Future<void> _leave() async {
    final router = GoRouter.of(context);
    try {
      await ref.read(conversationProvider(_id).notifier).leave();
      router.pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorCode = error.code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final me = ref.watch(meProvider.select((m) => m.value?.id));
    final conversation = widget.state.conversation;
    final messages = widget.state.messages;
    final showSender = conversation.kind != ConversationKind.direct;
    String nameOf(String userId) =>
        conversation.members.where((m) => m.userId == userId).firstOrNull?.firstName ??
        l10n.chatFormerMember;

    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          child: Text(
            conversationTitle(l10n, conversation, me),
            style: UmText.h3.copyWith(color: c.ink),
          ),
        ),
        actions: [
          if (conversation.kind == ConversationKind.group)
            IconButton(
              tooltip: l10n.chatLeave,
              icon: Icon(Icons.logout_rounded, color: c.brandStrong),
              onPressed: _leave,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(UmSpace.s6, 0, UmSpace.s6, UmSpace.s2),
              child: Text(
                conversationMembers(l10n, conversation, me),
                style: UmText.bodySm.copyWith(color: c.inkMuted),
              ),
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
                        horizontal: UmSpace.s6,
                        vertical: UmSpace.s3,
                      ),
                      itemCount: messages.length + (widget.state.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == messages.length) {
                          return Center(
                            child: UmButton(
                              label: l10n.chatOlder,
                              variant: UmButtonVariant.ghost,
                              onPressed: () =>
                                  ref.read(conversationProvider(_id).notifier).loadOlder(),
                            ),
                          );
                        }
                        final message = messages[messages.length - 1 - index];
                        final mine = message.senderId == me;
                        return _Bubble(
                          message: message,
                          mine: mine,
                          sender: showSender && !mine ? nameOf(message.senderId) : null,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(UmSpace.s6, UmSpace.s2, UmSpace.s3, UmSpace.s4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: UmField(
                        label: l10n.chatMessageLabel,
                        controller: _text,
                        maxLines: 4,
                        maxLength: 2000,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: UmSpace.s5),
                      child: IconButton(
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
                            : Icon(Icons.send_rounded, color: c.brandStrong),
                        onPressed: _sending ? null : _send,
                      ),
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine, this.sender});

  final ChatMessage message;
  final bool mine;
  final String? sender;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final time = formatTime(message.createdAt, l10n.localeName);
    final background = mine ? c.brand : c.surfaceRaised;
    final foreground = mine ? c.onBrand : c.ink;
    return Semantics(
      container: true,
      label: mine
          ? l10n.chatMineSemantic(message.body, time)
          : l10n.chatTheirsSemantic(sender ?? '', message.body, time),
      excludeSemantics: true,
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
          child: Container(
            margin: const EdgeInsets.only(bottom: UmSpace.s2),
            padding: const EdgeInsets.symmetric(horizontal: UmSpace.s4, vertical: UmSpace.s2),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(UmRadius.md),
              border: mine ? null : Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (sender != null)
                  Text(
                    sender!,
                    style: UmText.caption.copyWith(
                      color: c.brandStrong,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(message.body, style: UmText.body.copyWith(color: foreground)),
                Text(time, style: UmText.caption.copyWith(color: foreground)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
