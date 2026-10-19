import 'dart:ui' show ImageFilter;

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
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
/// dans le coin. Dans un groupe : photo de l'auteur à côté de son dernier message d'une série,
/// prénom en couleur propre au-dessus du premier. Photo éventuelle au-dessus de la légende ;
/// réactions en pastilles sous la bulle. Appui long : réactions, tous les emojis, copier.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.myId,
    this.sender,
    this.senderColor,
    this.avatar,
    this.avatarSlot = false,
    this.replyAuthor,
    this.replyColor,
    this.gapAfter = UmSpace.s2,
    this.onReact,
    this.onReply,
    this.onOpenPhoto,
  });

  final ChatMessage message;
  final bool mine;
  final String? myId;

  /// Prénom au-dessus de la bulle (premier message d'une série, dans un groupe).
  final String? sender;
  final Color? senderColor;

  /// Photo de l'auteur, à gauche du dernier message de sa série.
  final Widget? avatar;

  /// Réserver la place de la photo (groupe) pour que les bulles d'une série restent alignées.
  final bool avatarSlot;

  /// Auteur du message cité (prénom, « Toi ») et sa couleur.
  final String? replyAuthor;
  final Color? replyColor;

  /// Espace sous la bulle : plus grand en fin de série.
  final double gapAfter;

  /// Choisir ou retirer sa réaction (absent : conversation archivée).
  final ValueChanged<String?>? onReact;

  /// Répondre à ce message (glisser vers la droite, ou appui long) ; absent : archivée.
  final VoidCallback? onReply;
  final ValueChanged<String>? onOpenPhoto;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final time = formatTime(message.createdAt, l10n.localeName);
    final counts = message.reactionCounts;
    final myReaction = message.reactionOf(myId);

    final quote = message.replyTo;
    final semantic = [
      if (quote != null)
        l10n.chatReplySemantic(
          replyAuthor ?? '',
          quote.body.isEmpty ? l10n.chatPhotoSemantic : quote.body,
        ),
      if (message.photoUrl != null) l10n.chatPhotoSemantic,
      mine
          ? l10n.chatMineSemantic(message.body, time)
          : l10n.chatTheirsSemantic(sender ?? '', message.body, time),
      for (final (emoji, count) in counts) l10n.chatReactionSemantic(emoji, count),
    ].join('\n');

    final bubble = BubbleBody(
      message: message,
      mine: mine,
      sender: sender,
      senderColor: senderColor,
      replyAuthor: replyAuthor,
      replyColor: replyColor,
      onOpenPhoto: onOpenPhoto,
    );

    final column = Column(
      crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          label: semantic,
          excludeSemantics: true,
          onLongPressHint: onReact == null ? null : l10n.chatReact,
          onLongPress: onReact == null ? null : () => _actions(context),
          customSemanticsActions: onReply == null
              ? null
              : {CustomSemanticsAction(label: l10n.chatReply): onReply!},
          child: GestureDetector(onLongPress: () => _actions(context), child: bubble),
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
    );

    final row = Padding(
      padding: EdgeInsets.only(bottom: gapAfter + (counts.isEmpty ? 0 : UmSpace.s1)),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine && avatarSlot) ...[
            SizedBox(
              width: UmSize.avatar,
              child: avatar == null
                  ? null
                  : Padding(
                      // Aligné sur le bas de la bulle, au-dessus des réactions.
                      padding: EdgeInsets.only(bottom: counts.isEmpty ? 0 : UmSpace.s5),
                      child: ExcludeSemantics(child: avatar),
                    ),
            ),
            const SizedBox(width: UmSpace.s2),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
                  MediaQuery.sizeOf(context).width * UmSize.bubbleWidthFactor -
                  (avatarSlot ? UmSize.avatar + UmSpace.s2 : 0),
            ),
            child: column,
          ),
        ],
      ),
    );
    return onReply == null ? row : SwipeToReply(onReply: onReply!, child: row);
  }

  /// Appui long, comme dans une messagerie : le message se détache sur un fond flouté, avec
  /// les réactions rapides (et « + » pour tous les emojis) au-dessus et les actions dessous.
  Future<void> _actions(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await Navigator.of(context).push<_Action>(
      PageRouteBuilder<_Action>(
        opaque: false,
        barrierDismissible: true,
        barrierLabel: l10n.close,
        barrierColor: Colors.transparent,
        transitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        reverseTransitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 160),
        pageBuilder: (_, _, _) => _MessageActions(
          message: message,
          mine: mine,
          sender: sender,
          senderColor: senderColor,
          myReaction: message.reactionOf(myId),
          canReact: onReact != null,
          canReply: onReply != null,
          replyAuthor: replyAuthor,
          replyColor: replyColor,
        ),
        transitionsBuilder: (_, animation, _, child) => child,
      ),
    );
    switch (result) {
      case _React(:final emoji):
        onReact?.call(emoji);
      case _Reply():
        onReply?.call();
      case _Copy():
        await Clipboard.setData(ClipboardData(text: message.body));
        messenger.showSnackBar(SnackBar(content: Text(l10n.chatCopied)));
      case null:
        break;
    }
  }
}

/// Résultat du menu d'appui long.
sealed class _Action {
  const _Action();
}

class _React extends _Action {
  const _React(this.emoji);

  /// `null` : retirer sa réaction.
  final String? emoji;
}

class _Copy extends _Action {
  const _Copy();
}

class _Reply extends _Action {
  const _Reply();
}

/// Contenu d'une bulle (prénom, photo, texte et heure), sans les gestes : réutilisé tel quel
/// dans le menu d'appui long.
class BubbleBody extends StatelessWidget {
  const BubbleBody({
    super.key,
    required this.message,
    required this.mine,
    this.sender,
    this.senderColor,
    this.replyAuthor,
    this.replyColor,
    this.onOpenPhoto,
  });

  final ChatMessage message;
  final bool mine;
  final String? sender;
  final Color? senderColor;
  final String? replyAuthor;
  final Color? replyColor;
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

    return Container(
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
                style: UmText.caption.copyWith(
                  color: senderColor ?? c.brandStrong,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (message.replyTo case final quote?)
            Padding(
              padding: EdgeInsets.fromLTRB(
                photo == null ? 0 : UmSpace.s1,
                sender == null ? 0 : UmSpace.s1,
                photo == null ? 0 : UmSpace.s1,
                UmSpace.s1,
              ),
              child: QuoteBlock(
                quote: quote,
                author: replyAuthor ?? '',
                color: replyColor ?? c.brandStrong,
                onBrand: mine,
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
  }
}

/// Message cité en petit, au-dessus d'une réponse ou de la saisie : trait de la couleur de
/// l'auteur, son prénom, le début du texte.
class QuoteBlock extends StatelessWidget {
  const QuoteBlock({
    super.key,
    required this.quote,
    required this.author,
    required this.color,
    this.onBrand = false,
  });

  final MessageQuote quote;
  final String author;
  final Color color;

  /// Posé sur une bulle à moi (fond de marque) : couleurs claires.
  final bool onBrand;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final text = onBrand ? c.onBrand : c.ink;
    return ClipRRect(
      borderRadius: BorderRadius.circular(UmRadius.sm),
      child: Container(
        decoration: BoxDecoration(
          color: onBrand ? c.onBrand.withValues(alpha: 0.16) : c.surfaceTint,
          border: Border(
            left: BorderSide(color: onBrand ? c.onBrand : color, width: UmSpace.s1),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(UmSpace.s2, UmSpace.s1, UmSpace.s2, UmSpace.s1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: UmText.caption.copyWith(
                color: onBrand ? c.onBrand : color,
                fontWeight: FontWeight.w700,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (quote.hasPhoto) ...[
                  Icon(Icons.photo_outlined, size: UmSize.iconSm, color: text),
                  const SizedBox(width: UmSpace.s1),
                ],
                Flexible(
                  child: Text(
                    quote.body.isEmpty ? l10n.chatPhotoSemantic : quote.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: UmText.bodySm.copyWith(color: text),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Glisser un message vers la droite pour y répondre, comme dans une messagerie : la flèche
/// apparaît, un petit retour haptique au seuil, puis la bulle revient en place.
class SwipeToReply extends StatefulWidget {
  const SwipeToReply({super.key, required this.onReply, required this.child});

  final VoidCallback onReply;
  final Widget child;

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> with SingleTickerProviderStateMixin {
  static const _threshold = UmSize.tapTarget * 1.2;
  late final _offset = AnimationController(
    vsync: this,
    upperBound: _threshold * 1.4,
    duration: const Duration(milliseconds: 180),
  );
  bool _armed = false;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  void _update(DragUpdateDetails details) {
    _offset.value += details.delta.dx;
    final armed = _offset.value >= _threshold;
    if (armed && !_armed) HapticFeedback.selectionClick();
    _armed = armed;
  }

  void _end(DragEndDetails _) {
    if (_armed) widget.onReply();
    _armed = false;
    if (MediaQuery.disableAnimationsOf(context)) {
      _offset.value = 0;
    } else {
      _offset.animateTo(0, curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    return GestureDetector(
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: _end,
      onHorizontalDragCancel: () => _offset.value = 0,
      child: AnimatedBuilder(
        animation: _offset,
        builder: (context, child) => Stack(
          alignment: Alignment.centerLeft,
          children: [
            Opacity(
              opacity: (_offset.value / _threshold).clamp(0, 1),
              child: Padding(
                padding: const EdgeInsets.only(left: UmSpace.s2),
                child: CircleAvatar(
                  radius: UmSize.iconMd * 0.75,
                  backgroundColor: c.surfaceTint,
                  child: Icon(Icons.reply_rounded, size: UmSize.iconMd, color: c.brandStrong),
                ),
              ),
            ),
            Transform.translate(offset: Offset(_offset.value, 0), child: child),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

/// Menu d'appui long : fond flouté, barre de réactions qui s'ouvre en ressort, le message, puis
/// les actions (copier, retirer sa réaction). « + » ouvre tous les emojis.
class _MessageActions extends StatefulWidget {
  const _MessageActions({
    required this.message,
    required this.mine,
    required this.canReact,
    required this.canReply,
    this.sender,
    this.senderColor,
    this.myReaction,
    this.replyAuthor,
    this.replyColor,
  });

  final ChatMessage message;
  final bool mine;
  final bool canReact;
  final bool canReply;
  final String? sender;
  final Color? senderColor;
  final String? myReaction;
  final String? replyAuthor;
  final Color? replyColor;

  @override
  State<_MessageActions> createState() => _MessageActionsState();
}

class _MessageActionsState extends State<_MessageActions> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (_controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickAny() async {
    final navigator = Navigator.of(context);
    final emoji = await showEmojiPicker(context);
    if (emoji != null) navigator.pop(_React(emoji));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final align = widget.mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    // Ressort : la barre grandit un peu au-delà puis se pose ; le message se soulève.
    final pop = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    final fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    final reactions = Material(
      color: c.surfaceRaised,
      elevation: 6,
      shape: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: UmSpace.s1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, emoji) in chatReactions.indexed)
              // Chaque emoji arrive l'un après l'autre.
              ScaleTransition(
                scale: CurvedAnimation(
                  parent: _controller,
                  curve: Interval(
                    0.1 + i * 0.08,
                    (0.5 + i * 0.08).clamp(0, 1),
                    curve: Curves.elasticOut,
                  ),
                ),
                child: IconButton(
                  tooltip: l10n.chatReactWith(emoji),
                  isSelected: widget.myReaction == emoji,
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(UmSize.tapTarget),
                    backgroundColor: widget.myReaction == emoji ? c.lavender : null,
                  ),
                  icon: Text(emoji, style: const TextStyle(fontSize: UmSize.reactionChoice)),
                  onPressed: () =>
                      Navigator.of(context).pop(_React(widget.myReaction == emoji ? null : emoji)),
                ),
              ),
            IconButton(
              tooltip: l10n.chatReactMore,
              style: IconButton.styleFrom(
                minimumSize: const Size.square(UmSize.tapTarget),
                backgroundColor: c.surfaceTint,
              ),
              icon: Icon(Icons.add_rounded, color: c.brandStrong),
              onPressed: _pickAny,
            ),
          ],
        ),
      ),
    );

    final menu = Material(
      color: c.surfaceRaised,
      elevation: 6,
      borderRadius: BorderRadius.circular(UmRadius.md),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.canReply)
              ListTile(
                leading: Icon(Icons.reply_rounded, color: c.brandStrong),
                title: Text(l10n.chatReply),
                onTap: () => Navigator.of(context).pop(const _Reply()),
              ),
            if (widget.message.body.isNotEmpty)
              ListTile(
                leading: Icon(Icons.copy_rounded, color: c.brandStrong),
                title: Text(l10n.chatCopy),
                onTap: () => Navigator.of(context).pop(const _Copy()),
              ),
            if (widget.canReact && widget.myReaction != null)
              ListTile(
                leading: Icon(Icons.remove_circle_outline_rounded, color: c.brandStrong),
                title: Text(l10n.chatReactionRemove),
                onTap: () => Navigator.of(context).pop(const _React(null)),
              ),
          ],
        ),
      ),
    );

    // Material : les textes du menu ont leur style (sans le double soulignement jaune de Flutter).
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Fond flouté et adouci ; le toucher ferme.
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: FadeTransition(
                opacity: fade,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: ColoredBox(color: c.surface.withValues(alpha: 0.55)),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(UmSpace.s4),
                child: Column(
                  crossAxisAlignment: align,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.canReact)
                      ScaleTransition(
                        scale: pop,
                        alignment: widget.mine ? Alignment.bottomRight : Alignment.bottomLeft,
                        child: reactions,
                      ),
                    const SizedBox(height: UmSpace.s3),
                    ScaleTransition(
                      scale: Tween<double>(begin: 0.92, end: 1).animate(pop),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * UmSize.bubbleWidthFactor,
                        ),
                        child: BubbleBody(
                          message: widget.message,
                          mine: widget.mine,
                          sender: widget.sender,
                          senderColor: widget.senderColor,
                          replyAuthor: widget.replyAuthor,
                          replyColor: widget.replyColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: UmSpace.s3),
                    FadeTransition(opacity: fade, child: menu),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tous les emojis, comme au clavier (catégories, récents, teintes de peau).
Future<String?> showEmojiPicker(BuildContext context) => showModalBottomSheet<String>(
  context: context,
  showDragHandle: true,
  builder: (sheet) {
    final c = sheet.umColors;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(sheet).height * 0.45,
        child: EmojiPicker(
          onEmojiSelected: (_, emoji) => Navigator.of(sheet).pop(emoji.emoji),
          config: Config(
            emojiViewConfig: EmojiViewConfig(
              backgroundColor: c.surfaceRaised,
              emojiSizeMax: UmSize.reactionChoice,
            ),
            categoryViewConfig: CategoryViewConfig(
              backgroundColor: c.surfaceRaised,
              indicatorColor: c.brandStrong,
              iconColorSelected: c.brandStrong,
              iconColor: c.inkMuted,
            ),
            bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
            searchViewConfig: SearchViewConfig(backgroundColor: c.surfaceRaised),
          ),
        ),
      ),
    );
  },
);

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
