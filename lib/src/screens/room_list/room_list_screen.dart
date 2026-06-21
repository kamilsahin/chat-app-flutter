import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/chat_theme.dart';
import '../../models/message.dart';
import '../../models/room.dart';
import '../../providers/config_provider.dart';
import '../../providers/room_providers.dart';
import '../../providers/service_providers.dart';
import '../../services/stomp_service.dart';
import '../room/room_screen.dart';

class RoomListScreen extends ConsumerStatefulWidget {
  final Widget? drawer;
  final RoomType? typeFilter;
  const RoomListScreen({super.key, this.drawer, this.typeFilter});

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _connect();
  }

  void _connect() {
    final stomp = ref.read(stompServiceProvider);
    if (stomp.isConnected) {
      _stompConnected = true;
      _subscribeToLoadedRooms();
      _subscribeUserRooms();
      return;
    }
    stomp.connect(
      onConnected: () {
        if (_disposed) return;
        _stompConnected = true;
        _subscribeToLoadedRooms();
        _subscribeUserRooms();
      },
    );
  }

  void _subscribeToLoadedRooms() {
    if (_disposed || !_stompConnected) return;
    final rooms = ref.read(roomListProvider(widget.typeFilter)).valueOrNull ?? [];
    for (final room in rooms) {
      if (_subscribedRooms.contains(room.id)) continue;
      _subscribedRooms.add(room.id);
      _subscribeRoom(room.id);
    }
  }

  // Kullanıcının kişisel kanalına abone ol — yeni konuşma (listede olmayan oda)
  // mesajı gelince listeyi yenile, oda en üste gelsin.
  void _subscribeUserRooms() {
    if (_disposed || !_stompConnected) return;
    final userId = ref.read(chatConfigProvider).userId;
    ref.read(stompServiceProvider).subscribeUserRooms(userId, (roomId) {
      if (_disposed) return;
      // _subscribedRooms'a değil, o anki LİSTE durumuna bak: oda görünür listede
      // varsa room-topic onMsg zaten en üste taşıyor. Listede yoksa (silinmiş
      // konuşma ya da yepyeni oda) sessizce yenile → oda en üstte geri gelir.
      final rooms = ref.read(roomListProvider(widget.typeFilter)).valueOrNull ?? [];
      final inList = rooms.any((r) => r.id == roomId);
      if (inList) return;
      ref.read(roomListProvider(widget.typeFilter).notifier).silentRefresh();
    });
  }

  void _subscribeRoom(String roomId) {
    // Only update the room list tile — message list is managed by RoomScreen.
    void onMsg(Message message) {
      if (_disposed) return;
      // ref kullan — _container stale olabilir (ChatApp re-init durumunda).
      final currentUserId = ref.read(chatConfigProvider).userId;
      ref
          .read(roomListProvider(widget.typeFilter).notifier)
          .updateLastMessage(roomId, message, currentUserId);
    }

    _msgHandlers[roomId] = onMsg;

    ref
        .read(stompServiceProvider)
        .subscribeToRoom(roomId, onMessage: onMsg);
  }

  @override
  void dispose() {
    _disposed = true;
    // Remove our handlers without fully disconnecting (RoomScreen may still
    // have its own handlers for the active room). Then disconnect the client.
    for (final entry in _msgHandlers.entries) {
      ref
          .read(stompServiceProvider)
          .unsubscribeFromRoom(entry.key, onMessage: entry.value);
    }
    // disconnect() burada çağrılmıyor — RoomScreen gibi başka
    // ekranlar hâlâ STOMP'a ihtiyaç duyuyor olabilir.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to rooms as soon as they finish loading
    ref.listen(roomListProvider(widget.typeFilter), (_, next) {
      next.whenData((_) => _subscribeToLoadedRooms());
    });

    final filteredAsync = ref.watch(roomListProvider(widget.typeFilter));

    final t = context.chatTheme;
    return Scaffold(
      backgroundColor: t.scaffoldColor,
      drawer: widget.drawer,
      appBar: AppBar(
        backgroundColor: t.appBarBackgroundColor,
        title: Text(
          'Mesajlar',
          style: TextStyle(color: t.appBarForegroundColor, fontWeight: FontWeight.w600),
        ),
        iconTheme: IconThemeData(color: t.appBarForegroundColor),
      ),
      body: filteredAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: t.primaryColor),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(
                () {
                  final msg = e.toString();
                  final isConn = msg.contains('SocketException') ||
                      msg.contains('DioException') ||
                      msg.contains('Connection') ||
                      msg.contains('Null check operator') ||
                      msg.contains('HandshakeException');
                  return isConn ? 'Bağlantı hatası, lütfen tekrar deneyin.' : msg;
                }(),
                style: TextStyle(color: t.textMutedColor),
              ),
              TextButton(
                onPressed: () => ref.read(roomListProvider(widget.typeFilter).notifier).refresh(),
                child: Text('Tekrar Dene', style: TextStyle(color: t.primaryColor)),
              ),
            ],
          ),
        ),
        data: (rooms) {
          // Her render'da son mesaja göre sırala — WebSocket güncellemesi
          // sonrası oda en üste taşınsın.
          final sorted = [...rooms]
            ..sort((a, b) => (b.lastMessageAt ?? b.createdAt)
                .compareTo(a.lastMessageAt ?? a.createdAt));

          if (sorted.isEmpty) {
            return Center(
              child: Text(
                'Henüz sohbet yok',
                style: TextStyle(color: t.textMutedColor),
              ),
            );
          }

          return RefreshIndicator(
            color: t.primaryColor,
            onRefresh: () => ref.read(roomListProvider(widget.typeFilter).notifier).refresh(),
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollEndNotification &&
                    n.metrics.pixels >= n.metrics.maxScrollExtent - 100) {
                  ref.read(roomListProvider(widget.typeFilter).notifier).loadMore();
                }
                return false;
              },
              child: ListView.builder(
                itemCount: sorted.length +
                    (ref.watch(roomListProvider(widget.typeFilter).notifier).hasMore ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == sorted.length) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator(color: t.primaryColor)),
                    );
                  }
                  return _RoomTile(
                    room: sorted[i],
                    currentUserId: ref.read(chatConfigProvider).userId,
                    typeFilter: widget.typeFilter,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RoomTile extends ConsumerWidget {
  final Room room;
  final String currentUserId;
  final RoomType? typeFilter;
  const _RoomTile({required this.room, required this.currentUserId, this.typeFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = room.isMuted(currentUserId);
    final hasUnread = room.unreadCount > 0;
    final t = context.chatTheme;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatThemeProvider(
            theme: t,
            child: UncontrolledProviderScope(
              container: ProviderScope.containerOf(context),
              child: RoomScreen(
                roomId: room.id,
                title: room.name,
                typeFilter: typeFilter,
                roomType: room.type,
                avatarUrl: room.avatarUrl,
                otherUserId: room.otherUserId,
              ),
            ),
          ),
        ),
      ),
      onLongPress: () => _showMuteSheet(context, ref, muted),
      child: Container(
        decoration: BoxDecoration(
          color: hasUnread
              ? t.primaryColor.withValues(alpha: 0.05)
              : t.appBarColor,
          border: Border(
            bottom: BorderSide(color: t.scaffoldColor, width: 1.0),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar — DIRECT sohbette karşı kişinin profiline gider
            GestureDetector(
              onTap: () => _openProfile(ref),
              child: _Avatar(room: room, hasUnread: hasUnread),
            ),
            const SizedBox(width: 12),

            // Name + last message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          room.name ?? 'Sohbet',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: t.textColor,
                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (muted) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.notifications_off, size: 13, color: t.textMutedColor),
                      ],
                    ],
                  ),

                  // Last message
                  if (room.lastMessage != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      room.lastMessage!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasUnread
                            ? t.textColor.withValues(alpha: 0.75)
                            : t.textMutedColor,
                        fontSize: 13,
                        fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Timestamp + unread badge
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (room.lastMessageAt != null)
                  Text(
                    _formatTime(room.lastMessageAt!),
                    style: TextStyle(
                      color: hasUnread ? t.primaryColor : t.textMutedColor,
                      fontSize: 11,
                      fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                if (hasUnread) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: muted
                          ? t.textMutedColor.withValues(alpha: 0.45)
                          : t.primaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      room.unreadCount > 99 ? '99+' : '${room.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// DIRECT sohbette karşı kullanıcının profilini açar (host callback'i ile).
  void _openProfile(WidgetRef ref) {
    if (room.type != RoomType.direct) return;
    final otherId = room.otherUserId;
    if (otherId == null) return;
    ref.read(chatConfigProvider).onUserProfileTap?.call(otherId);
  }

  void _showMuteSheet(BuildContext context, WidgetRef ref, bool muted) {
    final t = context.chatTheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: t.appBarColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChatThemeProvider(
        theme: t,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: t.textMutedColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              if (muted) ...[
                ListTile(
                  leading: Icon(Icons.notifications, color: t.primaryColor),
                  title: Text('Bildirimleri aç', style: TextStyle(color: t.textColor)),
                  onTap: () {
                    Navigator.pop(context);
                    ref.read(roomListProvider(typeFilter).notifier).unmuteRoom(room.id, currentUserId);
                  },
                ),
              ] else ...[

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Ne kadar sessize alınsın?',
                        style: TextStyle(color: t.textMutedColor, fontSize: 13)),
                  ),
                ),
                _MuteOption(label: '1 saat', icon: Icons.notifications_off_outlined,
                    onTap: () { Navigator.pop(context); ref.read(roomListProvider(typeFilter).notifier).muteRoom(room.id, currentUserId, duration: 'PT1H'); }),
                _MuteOption(label: '8 saat', icon: Icons.notifications_off_outlined,
                    onTap: () { Navigator.pop(context); ref.read(roomListProvider(typeFilter).notifier).muteRoom(room.id, currentUserId, duration: 'PT8H'); }),
                _MuteOption(label: '1 hafta', icon: Icons.notifications_off_outlined,
                    onTap: () { Navigator.pop(context); ref.read(roomListProvider(typeFilter).notifier).muteRoom(room.id, currentUserId, duration: 'P7D'); }),
                _MuteOption(label: 'Kalıcı olarak sessize al', icon: Icons.notifications_off,
                    onTap: () { Navigator.pop(context); ref.read(roomListProvider(typeFilter).notifier).muteRoom(room.id, currentUserId); }),
              ],
              Divider(color: t.dividerColor, height: 1),
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                title: const Text('Sohbeti sil', style: TextStyle(color: Colors.redAccent)),
                onTap: () => _confirmClearHistory(context, ref),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmClearHistory(BuildContext context, WidgetRef ref) {
    final t = context.chatTheme;
    showDialog(
      context: context,
      useRootNavigator: false, // sheet ile aynı navigator → pop() doğru çalışır
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: t.appBarColor,
        title: Text('Sohbeti sil', style: TextStyle(color: t.textColor)),
        content: Text(
          'Bu sohbetin tüm geçmişi senin için silinecek. Karşı taraf mesajları görmeye devam eder.',
          style: TextStyle(color: t.textMutedColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('İptal', style: TextStyle(color: t.textMutedColor)),
          ),
          TextButton(
            onPressed: () {
              // ref ve nav'ı pop öncesi al — sonra widget dispose olur
              final notifier = ref.read(roomListProvider(typeFilter).notifier);
              Navigator.of(dialogCtx)
                ..pop()  // dialog kapat
                ..pop(); // sheet kapat
              notifier.clearHistory(room.id);
            },
            child: const Text('Sil', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    // Compare calendar days, not raw duration (avoids "23 hours = 0 days" bug)
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(time.year, time.month, time.day);
    final diff  = today.difference(d).inDays;

    if (diff == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    if (diff == 1) return 'Dün';
    if (diff < 7) {
      const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
      return days[time.weekday - 1];
    }
    const months = [
      'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
    ];
    if (time.year == now.year) {
      return '${time.day} ${months[time.month - 1]}';
    }
    return '${time.day} ${months[time.month - 1]} ${time.year}';
  }
}

class _MuteOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _MuteOption({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.chatTheme;
    return ListTile(
      leading: Icon(icon, color: t.iconColor),
      title: Text(label, style: TextStyle(color: t.textColor)),
      onTap: onTap,
    );
  }
}

class _Avatar extends ConsumerWidget {
  final Room room;
  final bool hasUnread;
  const _Avatar({required this.room, this.hasUnread = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.chatTheme;
    final serverUrl = ref.read(chatConfigProvider).apiUrl;

    Widget avatar;
    if (room.avatarUrl != null) {
      final url = room.avatarUrl!.startsWith('http')
          ? room.avatarUrl!
          : '$serverUrl${room.avatarUrl!}';
      avatar = CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(url),
        backgroundColor: t.inputColor,
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    } else {
      avatar = CircleAvatar(
        radius: 24,
        backgroundColor: t.inputColor,
        child: Icon(
          room.type == RoomType.group ? Icons.group : Icons.person,
          color: t.textMutedColor,
          size: 22,
        ),
      );
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: hasUnread
              ? t.primaryColor.withValues(alpha: 0.5)
              : t.dividerColor,
          width: hasUnread ? 2.0 : 1.0,
        ),
      ),
      child: ClipOval(child: avatar),
    );
  }
}
