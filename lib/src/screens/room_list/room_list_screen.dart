import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/message.dart';
import '../../models/room.dart';
import '../../providers/config_provider.dart';
import '../../providers/room_providers.dart';
import '../../providers/service_providers.dart';
import '../../services/stomp_service.dart';
import '../room/room_screen.dart';

class RoomListScreen extends ConsumerStatefulWidget {
  const RoomListScreen({super.key});

  @override
  ConsumerState<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends ConsumerState<RoomListScreen> {
  final _subscribedRooms = <String>{};
  // Store per-room callback references so we can remove them on dispose
  final Map<String, MessageCallback> _msgHandlers = {};
  bool _stompConnected = false;
  bool _disposed = false;
  bool _initialized = false;
  late ProviderContainer _container;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    // ProviderScope.containerOf uses dependOnInheritedWidgetOfExactType,
    // which must be called from didChangeDependencies, not initState.
    _container = ProviderScope.containerOf(context);
    _connect();
  }

  void _connect() {
    _container.read(stompServiceProvider).connect(onConnected: () {
      if (_disposed) return;
      _stompConnected = true;
      _subscribeToLoadedRooms();
    });
  }

  void _subscribeToLoadedRooms() {
    if (_disposed || !_stompConnected) return;
    final rooms = _container.read(roomListProvider).valueOrNull ?? [];
    for (final room in rooms) {
      if (_subscribedRooms.contains(room.id)) continue;
      _subscribedRooms.add(room.id);
      _subscribeRoom(room.id);
    }
  }

  void _subscribeRoom(String roomId) {
    // Only update the room list tile — message list is managed by RoomScreen.
    void onMsg(Message message) {
      if (_disposed) return;
      final currentUserId = _container.read(chatConfigProvider).userId;
      _container.read(roomListProvider.notifier).updateLastMessage(roomId, message, currentUserId);
    }
    _msgHandlers[roomId] = onMsg;

    _container.read(stompServiceProvider).subscribeToRoom(
      roomId,
      onMessage: onMsg,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    // Remove our handlers without fully disconnecting (RoomScreen may still
    // have its own handlers for the active room). Then disconnect the client.
    for (final entry in _msgHandlers.entries) {
      _container.read(stompServiceProvider).unsubscribeFromRoom(
        entry.key,
        onMessage: entry.value,
      );
    }
    _container.read(stompServiceProvider).disconnect();
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
                  itemBuilder: (context, i) => _RoomTile(
                    room: rooms[i],
                    currentUserId: ref.read(chatConfigProvider).userId,
                  ),
                ),
              ),
      ),
    );
  }
}

class _RoomTile extends ConsumerWidget {
  final Room room;
  final String currentUserId;
  const _RoomTile({required this.room, required this.currentUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = room.isMuted(currentUserId);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: _Avatar(room: room),
      title: Row(
        children: [
          Expanded(
            child: Text(
              room.name ?? 'Sohbet',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (muted)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.notifications_off,
                  size: 14, color: Colors.white38),
            ),
        ],
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
                color: muted
                    ? Colors.white24
                    : const Color(0xFF4CAF50),
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
      onLongPress: () => _showMuteSheet(context, ref, muted),
    );
  }

  void _showMuteSheet(BuildContext context, WidgetRef ref, bool muted) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            if (muted) ...[
              ListTile(
                leading: const Icon(Icons.notifications,
                    color: Color(0xFF4CAF50)),
                title: const Text('Bildirimleri aç',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(roomListProvider.notifier).unmuteRoom(room.id, currentUserId);
                },
              ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Ne kadar sessize alınsın?',
                      style: TextStyle(color: Colors.white54, fontSize: 13)),
                ),
              ),
              _MuteOption(
                label: '1 saat',
                icon: Icons.notifications_off_outlined,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(roomListProvider.notifier)
                      .muteRoom(room.id, currentUserId, duration: 'PT1H');
                },
              ),
              _MuteOption(
                label: '8 saat',
                icon: Icons.notifications_off_outlined,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(roomListProvider.notifier)
                      .muteRoom(room.id, currentUserId, duration: 'PT8H');
                },
              ),
              _MuteOption(
                label: '1 hafta',
                icon: Icons.notifications_off_outlined,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(roomListProvider.notifier)
                      .muteRoom(room.id, currentUserId, duration: 'P7D');
                },
              ),
              _MuteOption(
                label: 'Kalıcı olarak sessize al',
                icon: Icons.notifications_off,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(roomListProvider.notifier).muteRoom(room.id, currentUserId);
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
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

class _MuteOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _MuteOption({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
    );
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
