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

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    conversationId: json['conversationId'] as String,
    senderId: json['senderId'] as String,
    body: json['body'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;
}

class Conversation {
  const Conversation({
    required this.id,
    required this.kind,
    required this.members,
    required this.archived,
    required this.unread,
    this.title,
    this.rideId,
    this.lastMessage,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'] as String,
    kind: ConversationKind.values.byName(json['kind'] as String),
    title: json['title'] as String?,
    rideId: json['rideId'] as String?,
    archived: json['archived'] as bool,
    unread: json['unread'] as int,
    members: [
      for (final m in json['members'] as List<dynamic>)
        ChatMember.fromJson(m as Map<String, dynamic>),
    ],
    lastMessage: json['lastMessage'] == null
        ? null
        : ChatMessage.fromJson(json['lastMessage'] as Map<String, dynamic>),
  );

  final String id;
  final ConversationKind kind;
  final String? title;
  final String? rideId;

  /// Chat de trajet archivé : lecture seule (cahier §6).
  final bool archived;
  final int unread;
  final List<ChatMember> members;
  final ChatMessage? lastMessage;

  /// Les autres membres (pour le titre d'une conversation privée).
  List<ChatMember> others(String? me) => members.where((m) => m.userId != me).toList();

  Conversation copyWith({int? unread, ChatMessage? lastMessage}) => Conversation(
    id: id,
    kind: kind,
    title: title,
    rideId: rideId,
    archived: archived,
    unread: unread ?? this.unread,
    members: members,
    lastMessage: lastMessage ?? this.lastMessage,
  );
}
