import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/chat_theme.dart';
import '../../models/room.dart';
import '../../providers/service_providers.dart';
import 'room_screen.dart';

/// roomId'den sohbeti açar. Bildirime tıklama akışı için — bildirimde sadece
/// roomId taşınır, oda bilgisi (isim/avatar) backend'den çekilir.
///
/// [ChatApp.initialize] scope'u içinde kullanılmalı.
class RoomByIdScreen extends ConsumerStatefulWidget {
  final String roomId;

  const RoomByIdScreen({super.key, required this.roomId});

  @override
  ConsumerState<RoomByIdScreen> createState() => _RoomByIdScreenState();
}

class _RoomByIdScreenState extends ConsumerState<RoomByIdScreen> {
  late final Future<Room> _roomFuture;

  @override
  void initState() {
    super.initState();
    _roomFuture = ref.read(apiServiceProvider).getRoom(widget.roomId);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.chatTheme;
    return FutureBuilder<Room>(
      future: _roomFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: t.scaffoldColor,
            appBar: AppBar(
              backgroundColor: t.appBarBackgroundColor,
              iconTheme: IconThemeData(color: t.appBarForegroundColor),
            ),
            body: Center(child: CircularProgressIndicator(color: t.primaryColor)),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            backgroundColor: t.scaffoldColor,
            appBar: AppBar(
              backgroundColor: t.appBarBackgroundColor,
              iconTheme: IconThemeData(color: t.appBarForegroundColor),
            ),
            body: Center(
              child: Text(
                'Sohbet açılamadı',
                style: TextStyle(color: t.textMutedColor),
              ),
            ),
          );
        }

        final room = snapshot.data!;
        return RoomScreen(
          roomId: room.id,
          title: room.name,
          typeFilter: room.type == RoomType.direct ? RoomType.direct : null,
          roomType: room.type,
          avatarUrl: room.avatarUrl,
          otherUserId: room.otherUserId,
        );
      },
    );
  }
}
