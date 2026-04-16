import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/room.dart';
import '../models/message.dart';
import 'service_providers.dart';

// Room list
final roomListProvider = AsyncNotifierProvider<RoomListNotifier, List<Room>>(
  RoomListNotifier.new,
  dependencies: [apiServiceProvider],
);

class RoomListNotifier extends AsyncNotifier<List<Room>> {
  @override
  Future<List<Room>> build() async {
    return ref.watch(apiServiceProvider).getRooms();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(apiServiceProvider).getRooms(),
    );
  }

  void updateLastMessage(String roomId, Message message) {
    state.whenData((rooms) {
      final room = rooms.firstWhere((r) => r.id == roomId,
          orElse: () => rooms.first);
      // If the incoming message already exists in the list it's a reaction/edit
      // update — don't bump the unread counter or change the last-message text.
      final isUpdate = room.lastMessageAt != null &&
          !message.createdAt.isAfter(room.lastMessageAt!);

      state = AsyncData(rooms.map((r) {
        if (r.id != roomId) return r;
        if (isUpdate) return r; // reaction/edit: nothing changes in the tile
        return r.copyWith(
          lastMessage: message.isDeleted ? 'Mesaj silindi' : message.content,
          lastMessageAt: message.createdAt,
          unreadCount: r.unreadCount + 1,
        );
      }).toList()
        ..sort((a, b) => (b.lastMessageAt ?? b.createdAt)
            .compareTo(a.lastMessageAt ?? a.createdAt)));
    });
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
  @override
  Future<List<Message>> build(String roomId) async {
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
    state.whenData((messages) async {
      final older = await ref
          .read(apiServiceProvider)
          .getMessages(arg, cursor: cursor);
      state = AsyncData([...messages, ...older]);
    });
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
