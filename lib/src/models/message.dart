enum MessageType { text, image, location }

class MessageReaction {
  final String emoji;
  final List<String> userIds;

  const MessageReaction({required this.emoji, required this.userIds});

  factory MessageReaction.fromJson(Map<String, dynamic> json) => MessageReaction(
        emoji: json['emoji'] as String,
        userIds: List<String>.from(json['userIds'] as List),
      );
}

class MessageLocation {
  final double latitude;
  final double longitude;
  final String? address;

  const MessageLocation({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  factory MessageLocation.fromJson(Map<String, dynamic> json) => MessageLocation(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        address: json['address'] as String?,
      );
}

class Message {
  final String id;
  final String roomId;
  final String senderId;
  final MessageType type;
  final String? content;
  final String? replyTo;
  final String? forwardedFrom;
  final List<MessageReaction> reactions;
  final List<String> readByUserIds;
  final bool isDeleted;
  final bool isEdited;
  final DateTime? editedAt;
  final String? imageUrl;
  final MessageLocation? location;
  final bool isPinned;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.type,
    this.content,
    this.replyTo,
    this.forwardedFrom,
    this.reactions = const [],
    this.readByUserIds = const [],
    this.isDeleted = false,
    this.isEdited = false,
    this.editedAt,
    this.imageUrl,
    this.location,
    this.isPinned = false,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        roomId: json['roomId'] as String,
        senderId: json['senderId'] as String,
        type: _parseType(json['type'] as String),
        content: json['content'] as String?,
        replyTo: json['replyTo'] as String?,
        forwardedFrom: json['forwardedFrom'] as String?,
        reactions: (json['reactions'] as List? ?? [])
            .map((r) => MessageReaction.fromJson(r as Map<String, dynamic>))
            .toList(),
        readByUserIds: (json['readBy'] as List? ?? [])
            .map((r) => (r as Map<String, dynamic>)['userId'] as String)
            .toList(),
        isDeleted: json['deleted'] as bool? ?? false,
        isEdited: json['edited'] as bool? ?? false,
        editedAt: json['editedAt'] != null
            ? DateTime.parse(json['editedAt'] as String)
            : null,
        imageUrl: json['imageUrl'] as String?,
        location: json['location'] != null
            ? MessageLocation.fromJson(json['location'] as Map<String, dynamic>)
            : null,
        isPinned: json['pinned'] as bool? ?? false,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );

  static MessageType _parseType(String type) => switch (type) {
        'IMAGE' => MessageType.image,
        'LOCATION' => MessageType.location,
        _ => MessageType.text,
      };

  bool isReadBy(String userId) => readByUserIds.contains(userId);

  Message copyWith({List<MessageReaction>? reactions, List<String>? readByUserIds}) =>
      Message(
        id: id,
        roomId: roomId,
        senderId: senderId,
        type: type,
        content: content,
        replyTo: replyTo,
        forwardedFrom: forwardedFrom,
        reactions: reactions ?? this.reactions,
        readByUserIds: readByUserIds ?? this.readByUserIds,
        isDeleted: isDeleted,
        isEdited: isEdited,
        editedAt: editedAt,
        imageUrl: imageUrl,
        location: location,
        isPinned: isPinned,
        createdAt: createdAt,
      );
}
