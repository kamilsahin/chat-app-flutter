export 'src/config/chat_config.dart';
export 'src/config/chat_theme.dart';
export 'src/screens/room_list/room_list_screen.dart';
export 'src/screens/room/room_screen.dart';
export 'src/screens/room/direct_chat_screen.dart';
export 'src/screens/room/room_by_id_screen.dart';
export 'src/models/room.dart';
export 'src/models/message.dart';
export 'src/models/chat_user.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/config/chat_config.dart';
import 'src/config/chat_theme.dart';
import 'src/providers/config_provider.dart';
import 'src/providers/room_providers.dart';
import 'src/providers/service_providers.dart';

class ChatApp {
  ChatApp._();

  // Persists the container across initialize() calls for the same user session.
  // Prevents provider state (room list, unread counts, STOMP subscriptions)
  // from being reset every time the host app rebuilds the chat screen.
  static ProviderContainer? _container;
  static String? _cachedJwt;

  /// Host app calls this to embed the chat UI.
  /// The [ProviderContainer] is reused as long as [config.jwtToken] stays
  /// the same, so Riverpod state (unread counts, cached rooms, etc.) survives
  /// screen rebuilds and navigator push/pop cycles.
  ///
  /// Pass [ChatConfig.fcmToken] (from firebase_messaging) to enable push
  /// notifications — the package registers the token with the backend.
  static Widget initialize({
    required ChatConfig config,
    required Widget child,
  }) {
    if (_container == null || _cachedJwt != config.jwtToken) {
      // New user session — start fresh.
      _container?.dispose();
      _container = ProviderContainer(
        overrides: [chatConfigProvider.overrideWithValue(config)],
      );
      _cachedJwt = config.jwtToken;
    }

    return UncontrolledProviderScope(
      container: _container!,
      child: _ChatInitWidget(child: child),
    );
  }

  /// Call this on logout to release all resources (STOMP, HTTP, providers).
  static void reset() {
    _container?.dispose();
    _container = null;
    _cachedJwt = null;
  }

  /// Şu an açık olan chat odası ID'si.
  /// Kullanıcı bir odadaysa roomId döner, değilse null.
  /// NotificationService gibi dışarıdan okuyanlar için.
  static String? get activeRoomId => _container?.read(activeRoomProvider);

  /// Aktif oda ID'sini dışarıdan günceller.
  /// Örn: host app profil ekranına geçişte aktif odayı temizler,
  /// profil kapanınca geri yükler.
  static void setActiveRoom(String? roomId) {
    _container?.read(activeRoomProvider.notifier).state = roomId;
  }

  /// Aktif odanın mesaj listesini API'dan yeniden çeker.
  /// FCM odadaki mesajı bildirdiğinde ama STOMP henüz subscribe olmamışsa
  /// çağrılır; STOMP'un kaçırdığı mesajları yakalamak için.
  static void refreshActiveRoom() {
    final roomId = activeRoomId;
    if (roomId == null) return;
    _container?.read(messageListProvider(roomId).notifier).refresh();
  }

  /// ChatConfig'de tanımlanan tema primary rengi.
  /// Bildirim overlay'i gibi dış bileşenler tema rengini buradan okur.
  static Color? get notificationColor =>
      _container?.read(chatConfigProvider).theme.primaryColor;
}

class _ChatInitWidget extends ConsumerStatefulWidget {
  final Widget child;
  const _ChatInitWidget({required this.child});

  @override
  ConsumerState<_ChatInitWidget> createState() => _ChatInitWidgetState();
}

class _ChatInitWidgetState extends ConsumerState<_ChatInitWidget>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Start STOMP connection as soon as chat is initialized.
      // This covers notification-tap flows where RoomListScreen is never shown.
      ref.read(stompServiceProvider).connect(onConnected: () {});

      final config = ref.read(chatConfigProvider);
      if (config.fcmToken != null) {
        ref.read(apiServiceProvider).updateFcmToken(config.fcmToken!).ignore();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Uygulama ön plana gelince STOMP bağlı değilse hemen reconnect et.
  /// Android'de OS arka planda WebSocket'i kapatıyor; 5 saniyelik otomatik
  /// retry beklemek yerine resume anında bağlantıyı yenile.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final stomp = ref.read(stompServiceProvider);
      if (!stomp.isConnected) {
        stomp.connect(onConnected: () {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.read(chatConfigProvider).theme;
    return ChatThemeProvider(theme: theme, child: widget.child);
  }
}
