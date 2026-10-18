/// Messagerie (cahier §6) : conversations privées, groupes, chat de trajet.
enum ConversationKind { direct, group, ride }

class ChatMember {
  const ChatMember({required this.userId, required this.firstName, this.photoUrl});

  factory ChatMember.fromJson(Map<String, dynamic> json) => ChatMember(
    userId: json['userId'] as String,
    firstName: json['firstName'] as String,
    photoUrl: json['photoUrl'] as String?,
  );

  final String userId;
  final String firstName;
  final String? photoUrl;
}

typedef CarpoolJoin = ({String userId, String firstName, String rideId});

/// Proposition de covoiturage dans une conversation : un conducteur offre un trajet, ou un
/// passager en cherche un ; les autres l'acceptent d'un toucher.
class Carpool {
  const Carpool({
    required this.isOffer,
    required this.day,
    required this.toCampus,
    this.rideId,
    this.time,
    this.joined = const [],
  });

  factory Carpool.fromJson(Map<String, dynamic> json) => Carpool(
    isOffer: json['kind'] == 'offer',
    rideId: json['rideId'] as String?,
    day: DateTime.parse(json['day'] as String),
    toCampus: json['direction'] == 'to_campus',
    time: json['time'] == null ? null : DateTime.parse(json['time'] as String),
    joined: [
      for (final j in json['joined'] as List<dynamic>)
        (
          userId: (j as Map<String, dynamic>)['userId'] as String,
          firstName: j['firstName'] as String,
          rideId: j['rideId'] as String,
        ),
    ],
  );

  final bool isOffer;
  final String? rideId;
  final DateTime day;
  final bool toCampus;

  /// Heure du trajet proposé (offre).
  final DateTime? time;

  /// Personnes montées grâce à ce message, et dans quelle voiture.
  final List<CarpoolJoin> joined;

  /// Trajet où je suis grâce à ce message (j'ai proposé, ou je suis monté, ou j'ai pris
  /// quelqu'un), pour l'ouvrir d'un toucher.
  String? rideFor(String? myId, {required bool mine}) {
    if (isOffer) {
      return mine || joined.any((j) => j.userId == myId) ? rideId : null;
    }
    if (mine) return joined.firstOrNull?.rideId;
    return null;
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.carpool,
    this.reactions = const [],
    this.photoUrl,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    conversationId: json['conversationId'] as String,
    senderId: json['senderId'] as String,
    body: json['body'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    carpool: json['carpool'] == null
        ? null
        : Carpool.fromJson(json['carpool'] as Map<String, dynamic>),
    reactions: [
      for (final r in json['reactions'] as List<dynamic>? ?? const [])
        (userId: (r as Map<String, dynamic>)['userId'] as String, emoji: r['emoji'] as String),
    ],
    photoUrl: json['photoUrl'] as String?,
  );

  final String id;
  final String conversationId;
  final String senderId;

  /// Texte, ou légende d'une photo (peut alors être vide).
  final String body;
  final DateTime createdAt;
  final Carpool? carpool;

  /// Une réaction par personne.
  final List<({String userId, String emoji})> reactions;

  /// Photo jointe, chargée avec le jeton (membres seulement).
  final String? photoUrl;

  /// Réactions regroupées : emoji et nombre, dans l'ordre d'arrivée.
  List<(String, int)> get reactionCounts {
    final counts = <String, int>{};
    for (final r in reactions) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
    }
    return [for (final e in counts.entries) (e.key, e.value)];
  }

  String? reactionOf(String? userId) =>
      reactions.where((r) => r.userId == userId).firstOrNull?.emoji;

  ChatMessage copyWith({List<({String userId, String emoji})>? reactions}) => ChatMessage(
    id: id,
    conversationId: conversationId,
    senderId: senderId,
    body: body,
    createdAt: createdAt,
    carpool: carpool,
    reactions: reactions ?? this.reactions,
    photoUrl: photoUrl,
  );
}

/// Réactions possibles (jeu fermé, comme le serveur).
const chatReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

class Conversation {
  const Conversation({
    required this.id,
    required this.kind,
    required this.members,
    required this.archived,
    required this.unread,
    this.title,
    this.rideId,
    this.rideDay,
    this.rideToCampus,
    this.lastMessage,
    this.createdBy,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'] as String,
    kind: ConversationKind.values.byName(json['kind'] as String),
    title: json['title'] as String?,
    rideId: json['rideId'] as String?,
    rideDay: (json['ride'] as Map<String, dynamic>?) == null
        ? null
        : DateTime.parse((json['ride'] as Map<String, dynamic>)['day'] as String),
    rideToCampus: (json['ride'] as Map<String, dynamic>?)?['direction'] == null
        ? null
        : (json['ride'] as Map<String, dynamic>)['direction'] == 'to_campus',
    archived: json['archived'] as bool,
    unread: json['unread'] as int,
    members: [
      for (final m in json['members'] as List<dynamic>)
        ChatMember.fromJson(m as Map<String, dynamic>),
    ],
    lastMessage: json['lastMessage'] == null
        ? null
        : ChatMessage.fromJson(json['lastMessage'] as Map<String, dynamic>),
    createdBy: json['createdBy'] as String?,
  );

  final String id;
  final ConversationKind kind;

  /// Créateur d'un groupe : le seul qui peut en retirer quelqu'un.
  final String? createdBy;
  final String? title;
  final String? rideId;

  /// Chat de trajet : jour et sens, pour distinguer les trajets entre eux.
  final DateTime? rideDay;
  final bool? rideToCampus;

  /// Chat de trajet archivé : lecture seule (cahier §6).
  final bool archived;
  final int unread;
  final List<ChatMember> members;
  final ChatMessage? lastMessage;

  /// Les autres membres (pour le titre d'une conversation privée).
  List<ChatMember> others(String? me) => members.where((m) => m.userId != me).toList();

  Conversation copyWith({
    int? unread,
    ChatMessage? lastMessage,
    String? title,
    List<ChatMember>? members,
  }) => Conversation(
    id: id,
    kind: kind,
    title: title ?? this.title,
    rideId: rideId,
    rideDay: rideDay,
    rideToCampus: rideToCampus,
    archived: archived,
    unread: unread ?? this.unread,
    members: members ?? this.members,
    lastMessage: lastMessage ?? this.lastMessage,
    createdBy: createdBy,
  );
}
