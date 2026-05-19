class ChatUser {
  final String id;
  final String externalId;
  final String displayName;
  final String? nickname;
  final String? avatarUrl;
  final String? bio;
  final bool isOnline;
  final DateTime? lastSeen;

  const ChatUser({
    required this.id,
    required this.externalId,
    required this.displayName,
    this.nickname,
    this.avatarUrl,
    this.bio,
    this.isOnline = false,
    this.lastSeen,
  });

  /// Rumuz varsa onu, yoksa displayName'i döner.
  String get visibleName => nickname?.isNotEmpty == true ? nickname! : displayName;

  factory ChatUser.fromJson(Map<String, dynamic> json) => ChatUser(
        id: json['id'] as String,
        externalId: json['externalId'] as String,
        displayName: json['displayName'] as String,
        nickname: json['nickname'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        bio: json['bio'] as String?,
        isOnline: json['online'] as bool? ?? false,
        lastSeen: json['lastSeen'] != null
            ? DateTime.parse(json['lastSeen'] as String)
            : null,
      );

  ChatUser copyWith({bool? isOnline, DateTime? lastSeen}) => ChatUser(
        id: id,
        externalId: externalId,
        displayName: displayName,
        nickname: nickname,
        avatarUrl: avatarUrl,
        bio: bio,
        isOnline: isOnline ?? this.isOnline,
        lastSeen: lastSeen ?? this.lastSeen,
      );
}
