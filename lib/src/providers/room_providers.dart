import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/room.dart';
import '../models/message.dart';
import 'service_providers.dart';

// Currently open room — set by RoomScreen so unread count is not incremented
// while the user is actively viewing a room.
final activeRoomProvider = StateProvider<String?>((ref) => null);

// Room list
final roomListProvider =
    AsyncNotifierProvider.family<RoomListNotifier, List<Room>, RoomType?>(
  RoomListNotifier.new,
  dependencies: [apiServiceProvider],
);

class RoomListNotifier extends FamilyAsyncNotifier<List<Room>, RoomType?> {
  int _page = 0;
  bool _hasNext = false;
  bool _loadingMore = false;

  String? get _typeParam => switch (arg) {
        RoomType.direct => 'DIRECT',
        RoomType.group => 'GROUP',
        null => null,
      };

  @override
  Future<List<Room>> build(RoomType? arg) async {
    _page = 0;
    final result = await ref.watch(apiServiceProvider).getRooms(type: _typeParam, page: 0);
    _hasNext = result.hasNext;
    _page = 1;
    return result.rooms;
  }

  Future<void> refresh() async {
    _page = 0;
    _hasNext = false;
    _loadingMore = false;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await ref.read(apiServiceProvider).getRooms(type: _typeParam, page: 0);
      _hasNext = result.hasNext;
      _page = 1;
      return result.rooms;
    });
  }

  /// Loading state göstermeden listeyi tazeler (real-time yeni konuşma için).
  /// Mevcut liste ekranda kalır, sessizce ilk sayfa yeniden çekilir.
  Future<void> silentRefresh() async {
    final result = await ref.read(apiServiceProvider).getRooms(type: _typeParam, page: 0);
    _hasNext = result.hasNext;
    _page = 1;
    state = AsyncData(result.rooms);
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasNext) return;
    _loadingMore = true;
    try {
      final result = await ref.read(apiServiceProvider).getRooms(type: _typeParam, page: _page);
      state.whenData((rooms) {
        state = AsyncData([...rooms, ...result.rooms]);
        _hasNext = result.hasNext;
        _page++;
      });
    } finally {
      _loadingMore = false;
    }
  }

  bool get hasMore => _hasNext;

  void updateLastMessage(String roomId, Message message, String currentUserId) {
    state.whenData((rooms) {
      // If the room isn't in the loaded list, nothing to update.
      if (!rooms.any((r) => r.id == roomId)) return;

      final isOwn    = message.senderId == currentUserId;
      final isActive = ref.read(activeRoomProvider) == roomId;

      state = AsyncData(rooms.map((r) {
        if (r.id != roomId) return r;
        // Strictly older messages are stale — equal timestamps are fine
        // (!isAfter ile eşit timestamp'ler de skip ediliyordu, düzeltildi).
        final isStale = r.lastMessageAt != null &&
            message.createdAt.isBefore(r.lastMessageAt!);
        if (isStale) return r;

        String? preview;
        if (message.isDeleted) {
          preview = 'Mesaj silindi';
        } else if (message.type == MessageType.image) {
          preview = '📷 Fotoğraf';
        } else {
          preview = message.content;
        }

        return r.copyWith(
          lastMessage:   preview,
          lastMessageAt: message.createdAt,
          unreadCount:   (isOwn || isActive) ? r.unreadCount : r.unreadCount + 1,
        );
      }).toList()
        ..sort((a, b) => (b.lastMessageAt ?? b.createdAt)
            .compareTo(a.lastMessageAt ?? a.createdAt)));
    });
  }

  Future<void> clearHistory(String roomId) async {
    await ref.read(apiServiceProvider).clearHistory(roomId);
    // Odayı listeden kaldır — kullanıcı için artık içerik yok
    state.whenData((rooms) {
      state = AsyncData(rooms.where((r) => r.id != roomId).toList());
    });
  }

  Future<void> muteRoom(String roomId, String userId, {String? duration}) async {
    final mutedUntil = duration != null ? _parseUntil(duration) : null;
    _patchMember(roomId, userId, muted: true, mutedUntil: mutedUntil);
    await ref.read(apiServiceProvider).muteRoom(roomId, duration: duration);
  }

  Future<void> unmuteRoom(String roomId, String userId) async {
    _patchMember(roomId, userId, muted: false, mutedUntil: null);
    await ref.read(apiServiceProvider).unmuteRoom(roomId);
  }

  void _patchMember(String roomId, String userId, {required bool muted, DateTime? mutedUntil}) {
    state.whenData((rooms) {
      state = AsyncData(rooms.map((r) {
        if (r.id != roomId) return r;
        final members = r.members.map((m) {
          if (m.userId != userId) return m;
          return RoomMember(
            userId: m.userId,
            role: m.role,
            joinedAt: m.joinedAt,
            muted: muted,
            mutedUntil: mutedUntil,
          );
        }).toList();
        return r.copyWith(members: members);
      }).toList());
    });
  }

  /// Parses simple ISO-8601 durations used in the mute sheet.
  static DateTime _parseUntil(String duration) {
    final now = DateTime.now();
    return switch (duration) {
      'PT1H' => now.add(const Duration(hours: 1)),
      'PT8H' => now.add(const Duration(hours: 8)),
      'P7D'  => now.add(const Duration(days: 7)),
      _      => now.add(const Duration(days: 3650)),
    };
  }

  void clearUnread(String roomId) {
    state.whenData((rooms) {
      state = AsyncData(rooms.map((r) {
        if (r.id != roomId) return r;
        return r.copyWith(unreadCount: 0);
      }).toList());
    });
  }
}

// Messages for a room
final messageListProvider =
    AsyncNotifierProvider.family<MessageListNotifier, List<Message>, String>(
  MessageListNotifier.new,
  dependencies: [apiServiceProvider],
);

class MessageListNotifier
    extends FamilyAsyncNotifier<List<Message>, String> {
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  @override
  Future<List<Message>> build(String roomId) async {
    _hasMore = true;
    return ref.watch(apiServiceProvider).getMessages(roomId);
  }

  void addMessage(Message message) {
    state.whenData((messages) {
      // Reaction/edit updates arrive on the same STOMP topic as new messages.
      // If a message with this id already exists, update it in place instead
      // of prepending a duplicate.
      final idx = messages.indexWhere((m) => m.id == message.id);
      if (idx != -1) {
        final copy = List<Message>.from(messages);
        copy[idx] = message;
        state = AsyncData(copy);
      } else {
        state = AsyncData([message, ...messages]);
      }
    });
  }

  void updateMessage(Message updated) {
    state.whenData((messages) {
      state = AsyncData(messages.map((m) {
        return m.id == updated.id ? updated : m;
      }).toList());
    });
  }

  Future<void> loadMore(String cursor) async {
    if (!_hasMore) return;
    final current = state.valueOrNull;
    if (current == null) return;
    final older = await ref
        .read(apiServiceProvider)
        .getMessages(arg, cursor: cursor);
    if (older.isNotEmpty) {
      state = AsyncData([...current, ...older]);
    } else {
      _hasMore = false; // daha mesaj yok, tekrar sorgulanmasın
    }
  }
}

// Per-room typing users
final typingProvider =
    NotifierProvider.family<TypingNotifier, Set<String>, String>(
  TypingNotifier.new,
);

class TypingNotifier extends FamilyNotifier<Set<String>, String> {
  @override
  Set<String> build(String arg) => {};

  void setTyping(String userId, bool isTyping) {
    if (isTyping) {
      state = {...state, userId};
    } else {
      state = state.difference({userId});
    }
  }
}

// Pinned message
final pinnedMessageProvider =
    FutureProvider.family<Message?, String>(
  (ref, roomId) => ref.watch(apiServiceProvider).getPinnedMessage(roomId),
  dependencies: [apiServiceProvider],
);
