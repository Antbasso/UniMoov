import '../../../l10n/app_localizations.dart';
import '../domain/chat.dart';

/// Titre d'une conversation : nom du groupe, prénom de l'autre personne, ou chat du trajet.
String conversationTitle(AppLocalizations l10n, Conversation c, String? me) => switch (c.kind) {
  ConversationKind.group => c.title ?? l10n.chatGroup,
  ConversationKind.ride => l10n.chatRideTitle,
  ConversationKind.direct => c.others(me).map((m) => m.firstName).join(', '),
};

/// Membres en clair (prénoms), sans soi-même.
String conversationMembers(AppLocalizations l10n, Conversation c, String? me) =>
    l10n.chatWith(c.others(me).map((m) => m.firstName).join(', '));
