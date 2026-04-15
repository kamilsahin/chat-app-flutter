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
      state = AsyncData(rooms.map((r) {
        if (r.id != roomId) return r;
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
      state = AsyncData([message, ...messages]);
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

// Pinned message
final pinnedMessageProvider =
    FutureProvider.family<Message?, String>(
  (ref, roomId) => ref.watch(apiServiceProvider).getPinnedMessage(roomId),
  dependencies: [apiServiceProvider],
);
