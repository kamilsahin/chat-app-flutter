import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/room.dart';
import '../../providers/room_providers.dart';
import '../../providers/service_providers.dart';
import '../room/room_screen.dart';

class RoomListScreen extends ConsumerStatefulWidget {
  const RoomListScreen({super.key});

  @override
  ConsumerState<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends ConsumerState<RoomListScreen> {
  final _subscribedRooms = <String>{};
  bool _stompConnected = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  void _connect() {
    ref.read(stompServiceProvider).connect(onConnected: () {
      if (_disposed) return;
      _stompConnected = true;
      _subscribeToLoadedRooms();
    });
  }

  void _subscribeToLoadedRooms() {
    if (_disposed || !_stompConnected) return;
    final rooms = ref.read(roomListProvider).valueOrNull ?? [];
    for (final room in rooms) {
      if (_subscribedRooms.contains(room.id)) continue;
      _subscribedRooms.add(room.id);
      _subscribeRoom(room.id);
    }
  }

  void _subscribeRoom(String roomId) {
    ref.read(stompServiceProvider).subscribeToRoom(
      roomId,
      onMessage: (message) {
        if (_disposed) return;
        // Always update the room list tile (last message, unread count)
        ref.read(roomListProvider.notifier).updateLastMessage(roomId, message);
        // Only append to message list when this room is open
        if (ref.read(activeRoomProvider) == roomId) {
          ref.read(messageListProvider(roomId).notifier).addMessage(message);
        }
      },
      onTyping: (userId, typing) {
        if (_disposed) return;
        ref.read(typingProvider(roomId).notifier).setTyping(userId, typing);
      },
      onPresence: (_, __) {},
    );
  }

  @override
  void dispose() {
    _disposed = true;
    ref.read(stompServiceProvider).disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to rooms as soon as they finish loading
    ref.listen(roomListProvider, (_, next) {
      next.whenData((_) => _subscribeToLoadedRooms());
    });

    final roomsAsync = ref.watch(roomListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Mesajlar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: roomsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(e.toString(), style: const TextStyle(color: Colors.white70)),
              TextButton(
                onPressed: () => ref.read(roomListProvider.notifier).refresh(),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
        data: (rooms) => rooms.isEmpty
            ? const Center(
                child: Text(
                  'Henüz sohbet yok',
                  style: TextStyle(color: Colors.white54),
                ),
              )
            : RefreshIndicator(
                onRefresh: () =>
                    ref.read(roomListProvider.notifier).refresh(),
                child: ListView.separated(
                  itemCount: rooms.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    color: Color(0xFF2A2A2A),
                    indent: 72,
                  ),
                  itemBuilder: (context, i) => _RoomTile(room: rooms[i]),
                ),
              ),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  final Room room;
  const _RoomTile({required this.room});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: _Avatar(room: room),
      title: Text(
        room.name ?? 'Sohbet',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: room.lastMessage != null
          ? Text(
              room.lastMessage!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            )
          : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (room.lastMessageAt != null)
            Text(
              _formatTime(room.lastMessageAt!),
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          if (room.unreadCount > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                room.unreadCount > 99 ? '99+' : '${room.unreadCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UncontrolledProviderScope(
            container: ProviderScope.containerOf(context),
            child: RoomScreen(roomId: room.id),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Dün';
    } else if (diff.inDays < 7) {
      const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
      return days[time.weekday - 1];
    }
    return '${time.day}/${time.month}/${time.year}';
  }
}

class _Avatar extends StatelessWidget {
  final Room room;
  const _Avatar({required this.room});

  @override
  Widget build(BuildContext context) {
    if (room.avatarUrl != null) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(room.avatarUrl!),
      );
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFF2A2A2A),
      child: Icon(
        room.type == RoomType.group ? Icons.group : Icons.person,
        color: Colors.white54,
      ),
    );
  }
}
