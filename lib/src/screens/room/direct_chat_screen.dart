import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/chat_theme.dart';
import '../../models/room.dart';
import '../../providers/service_providers.dart';
import 'room_screen.dart';

/// Bir kullanıcıyla DIRECT sohbeti açar. Önce backend'den odayı bul/oluştur,
/// sonra [RoomScreen] göster. Profil ekranından "Mesaj yaz" akışı için.
///
/// [ChatApp.initialize] scope'u içinde kullanılmalı (apiServiceProvider erişimi).
class DirectChatScreen extends ConsumerStatefulWidget {
  /// Karşı kullanıcının externalId'si.
  final String otherUserId;

  const DirectChatScreen({super.key, required this.otherUserId});

  @override
  ConsumerState<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends ConsumerState<DirectChatScreen> {
  late final Future<Room> _roomFuture;

  @override
  void initState() {
    super.initState();
    _roomFuture = ref.read(apiServiceProvider).createDirectRoom(widget.otherUserId);
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
          typeFilter: RoomType.direct,
          roomType: RoomType.direct,
          avatarUrl: room.avatarUrl,
          otherUserId: room.otherUserId ?? widget.otherUserId,
        );
      },
    );
  }
}
