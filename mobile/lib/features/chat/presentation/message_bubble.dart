import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/um_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/data/profile_api.dart';
import '../../proposals/presentation/formatting.dart';
import '../domain/chat.dart';

/// Photo d'un message, chargée avec le jeton et libérée en quittant la conversation.
final chatPhotoProvider = FutureProvider.autoDispose.family<Uint8List, String>(
  (ref, url) => ref.watch(profileApiProvider).photo(url),
  retry: (retryCount, error) => null,
);

/// Bulle de message, façon messagerie : large (jusqu'à 86 % de l'écran), compacte, l'heure
/// dans le coin, le prénom de l'auteur en petit dans un groupe. Photo éventuelle au-dessus de
/// la légende ; réactions en pastilles sous la bulle. Appui long : réagir.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.myId,
    this.sender,
    this.onReact,
    this.onOpenPhoto,
  });

  final ChatMessage message;
  final bool mine;
  final String? myId;
  final String? sender;

  /// Choisir ou retirer sa réaction (absent : conversation archivée).
  final ValueChanged<String?>? onReact;
  final ValueChanged<String>? onOpenPhoto;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final time = formatTime(message.createdAt, l10n.localeName);
    final background = mine ? c.brand : c.surfaceRaised;
    final foreground = mine ? c.onBrand : c.ink;
    final timeStyle = UmText.caption.copyWith(color: mine ? foreground : c.inkMuted);
    final body = message.body;
    final photo = message.photoUrl;
    final counts = message.reactionCounts;
    final myReaction = message.reactionOf(myId);

    // L'heure dans le coin, à droite du texte : la bulle reste basse.
    final text = body.isEmpty
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(body, style: UmText.body.copyWith(color: foreground)),
              ),
              const SizedBox(width: UmSpace.s2),
              Text(time, style: timeStyle),
            ],
          );

    final bubble = Container(
      padding: EdgeInsets.fromLTRB(
        photo == null ? UmSpace.s3 : UmSpace.s1,
        photo == null ? UmSpace.s2 : UmSpace.s1,
        photo == null ? UmSpace.s3 : UmSpace.s1,
        UmSpace.s1,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(UmRadius.md),
          topRight: const Radius.circular(UmRadius.md),
          bottomLeft: Radius.circular(mine ? UmRadius.md : UmSpace.s1),
          bottomRight: Radius.circular(mine ? UmSpace.s1 : UmRadius.md),
        ),
        border: mine ? null : Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sender != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: photo == null ? 0 : UmSpace.s2),
              child: Text(
                sender!,
                style: UmText.caption.copyWith(color: c.brandStrong, fontWeight: FontWeight.w600),
              ),
            ),
          if (photo != null)
            _ChatPhoto(url: photo, onTap: onOpenPhoto == null ? null : () => onOpenPhoto!(photo)),
          if (text != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                photo == null ? 0 : UmSpace.s2,
                photo == null ? 0 : UmSpace.s1,
                photo == null ? 0 : UmSpace.s2,
                photo == null ? 0 : UmSpace.s1,
              ),
              child: text,
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: UmSpace.s2),
                child: Text(time, style: timeStyle),
              ),
            ),
        ],
      ),
    );

    final semantic = [
      if (photo != null) l10n.chatPhotoSemantic,
      mine ? l10n.chatMineSemantic(body, time) : l10n.chatTheirsSemantic(sender ?? '', body, time),
      for (final (emoji, count) in counts) l10n.chatReactionSemantic(emoji, count),
    ].join('\n');

    return Padding(
      padding: EdgeInsets.only(bottom: counts.isEmpty ? UmSpace.s1 : UmSpace.s3),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * UmSize.bubbleWidthFactor,
          ),
          child: Column(
            crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Semantics(
                container: true,
                label: semantic,
                excludeSemantics: true,
                onLongPressHint: onReact == null ? null : l10n.chatReact,
                onLongPress: onReact == null ? null : () => _pickReaction(context),
                child: GestureDetector(
                  onLongPress: onReact == null ? null : () => _pickReaction(context),
                  child: bubble,
                ),
              ),
              if (counts.isNotEmpty)
                Transform.translate(
                  offset: const Offset(0, -UmSpace.s1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: UmSpace.s2),
                    child: Wrap(
                      spacing: UmSpace.s1,
                      runSpacing: UmSpace.s1,
                      children: [
                        for (final (emoji, count) in counts)
                          _ReactionPill(
                            emoji: emoji,
                            count: count,
                            mine: myReaction == emoji,
                            // Toucher sa réaction la retire, une autre la remplace.
                            onTap: onReact == null
                                ? null
                                : () => onReact!(myReaction == emoji ? null : emoji),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickReaction(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final current = message.reactionOf(myId);
    final choice = await showModalBottomSheet<(String?,)>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(UmSpace.s4, 0, UmSpace.s4, UmSpace.s4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.chatReact, style: UmText.h3.copyWith(color: sheet.umColors.ink)),
              const SizedBox(height: UmSpace.s3),
              Wrap(
                alignment: WrapAlignment.spaceEvenly,
                children: [
                  for (final emoji in chatReactions)
                    IconButton(
                      tooltip: l10n.chatReactWith(emoji),
                      isSelected: current == emoji,
                      style: IconButton.styleFrom(
                        minimumSize: const Size.square(UmSize.tapTarget),
                        backgroundColor: current == emoji ? sheet.umColors.lavender : null,
                      ),
                      icon: Text(emoji, style: const TextStyle(fontSize: UmSize.reactionChoice)),
                      onPressed: () => Navigator.of(sheet).pop((emoji,)),
                    ),
                ],
              ),
              if (current != null) ...[
                const SizedBox(height: UmSpace.s2),
                TextButton(
                  onPressed: () => Navigator.of(sheet).pop((null,)),
                  child: Text(l10n.chatReactionRemove),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (choice != null) onReact?.call(choice.$1);
  }
}

/// Pastille de réaction sous la bulle : emoji et nombre ; la mienne est soulignée d'un contour.
/// Nœud de lecture d'écran à part (sinon fondu dans l'élément de liste).
class _ReactionPill extends StatelessWidget {
  const _ReactionPill({required this.emoji, required this.count, required this.mine, this.onTap});

  final String emoji;
  final int count;
  final bool mine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    return Semantics(
      container: true,
      button: onTap != null,
      label: mine
          ? l10n.chatReactionMineSemantic(emoji, count)
          : l10n.chatReactionSemantic(emoji, count),
      excludeSemantics: true,
      child: Material(
        color: mine ? c.lavender : c.surfaceRaised,
        shape: StadiumBorder(side: BorderSide(color: mine ? c.brandStrong : c.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: UmSpace.s2, vertical: UmSpace.s1 / 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: UmSize.reactionEmoji)),
                if (count > 1) ...[
                  const SizedBox(width: UmSpace.s1),
                  Text('$count', style: UmText.caption.copyWith(color: c.ink)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatPhoto extends ConsumerWidget {
  const _ChatPhoto({required this.url, this.onTap});

  final String url;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.umColors;
    final bytes = ref.watch(chatPhotoProvider(url)).value;
    return ClipRRect(
      borderRadius: BorderRadius.circular(UmRadius.md - UmSpace.s1),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: UmSize.chatPhotoMaxHeight,
          minHeight: UmSize.tapTarget * 2,
          minWidth: double.infinity,
        ),
        child: bytes == null
            ? ColoredBox(
                color: c.surfaceTint,
                child: Center(child: Icon(Icons.image_outlined, color: c.inkMuted)),
              )
            : GestureDetector(
                onTap: onTap,
                child: Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
              ),
      ),
    );
  }
}

/// Photo en grand (pincer pour zoomer), fermée d'un geste ou par le bouton.
Future<void> showChatPhoto(BuildContext context, String url) => showDialog<void>(
  context: context,
  builder: (dialog) {
    final l10n = AppLocalizations.of(dialog);
    return Dialog.fullscreen(
      backgroundColor: dialog.umColors.ink,
      child: Stack(
        children: [
          Positioned.fill(
            child: Consumer(
              builder: (context, ref, _) => switch (ref.watch(chatPhotoProvider(url)).value) {
                final bytes? => InteractiveViewer(
                  child: Center(child: Image.memory(bytes, semanticLabel: l10n.chatPhotoSemantic)),
                ),
                null => const Center(child: CircularProgressIndicator()),
              },
            ),
          ),
          SafeArea(
            child: IconButton(
              tooltip: l10n.close,
              icon: Icon(Icons.close_rounded, color: dialog.umColors.surface),
              onPressed: () => Navigator.of(dialog).pop(),
            ),
          ),
        ],
      ),
    );
  },
);
