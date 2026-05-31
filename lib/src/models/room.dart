enum RoomType { direct, group }

enum MemberRole { admin, member }

class RoomMember {
  final String userId;
  final MemberRole role;
  final DateTime joinedAt;
  final bool muted;
  final DateTime? mutedUntil;

  const RoomMember({
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.muted = false,
    this.mutedUntil,
  });

  factory RoomMember.fromJson(Map<String, dynamic> json) => RoomMember(
        userId: json['userId'] as String,
        role: json['role'] == 'ADMIN' ? MemberRole.admin : MemberRole.member,
        joinedAt: DateTime.parse(json['joinedAt'] as String),
        muted: json['muted'] as bool? ?? false,
        mutedUntil: json['mutedUntil'] != null
            ? DateTime.parse(json['mutedUntil'] as String)
            : null,
      );
}

class Room {
  final String id;
  final RoomType type;
  final String? name;
  final String? avatarUrl;
  final List<RoomMember> members;
  final DateTime createdAt;

  // Populated client-side
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const Room({
    required this.id,
    required this.type,
    this.name,
    this.avatarUrl,
    required this.members,
    required this.createdAt,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        id: json['id'] as String,
        type: json['type'] == 'GROUP' ? RoomType.group : RoomType.direct,
        name: json['name'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        members: (json['members'] as List)
            .map((m) => RoomMember.fromJson(m as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastMessage: json['lastMessage'] as String?,
        lastMessageAt: json['lastActivityAt'] != null
            ? DateTime.parse(json['lastActivityAt'] as String)
            : null,
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      );

  bool isMuted(String currentUserId) {
    final member = members.where((m) => m.userId == currentUserId).firstOrNull;
    if (member == null || !member.muted) return false;
    if (member.mutedUntil == null) return true;
    return DateTime.now().isBefore(member.mutedUntil!);
  }

  Room copyWith({
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
    List<RoomMember>? members,
  }) =>
      Room(
        id: id,
        type: type,
        name: name,
        avatarUrl: avatarUrl,
        members: members ?? this.members,
        createdAt: createdAt,
        lastMessage: lastMessage ?? this.lastMessage,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        unreadCount: unreadCount ?? this.unreadCount,
      );
}
