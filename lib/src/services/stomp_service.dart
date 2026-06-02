import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../config/chat_config.dart';
import '../models/message.dart';

typedef MessageCallback = void Function(Message message);
typedef TypingCallback = void Function(String userId, bool typing);
typedef PresenceCallback = void Function(String userId, bool online);
typedef VoidCallback = void Function();

/// Each room has a single STOMP subscription. Multiple callers can register
/// handlers (observer pattern). The STOMP subscription is kept alive until
/// ALL handlers for a room are removed.
class StompService {
  final ChatConfig _config;
  StompClient? _client;

  // STOMP-level subscriptions (one entry per subscribed room)
  final Map<String, List<StompUnsubscribe>> _subscriptions = {};

  // Per-room handler lists (multiple observers allowed)
  final Map<String, List<MessageCallback>> _messageHandlers = {};
  final Map<String, List<TypingCallback>> _typingHandlers = {};

  // Kullanıcıya özel oda-aktivite kanalı (yeni konuşma bildirimi için)
  StompUnsubscribe? _userRoomsSub;

  StompService(this._config);

  void connect({required VoidCallback onConnected}) {
    _client = StompClient(
      config: StompConfig.sockJS(
        url: '${_config.serverUrl}/ws',
        stompConnectHeaders: {
          'Authorization': 'Bearer ${_config.jwtToken}',
        },
        onConnect: (frame) => onConnected(),
        onDisconnect: (_) {},
        onStompError: (_) {},
        onWebSocketError: (_) {},
        reconnectDelay: const Duration(seconds: 5),
      ),
    );
    _client!.activate();
  }

  void disconnect() {
    _client?.deactivate();
    _subscriptions.clear();
    _messageHandlers.clear();
    _typingHandlers.clear();
    _userRoomsSub = null;
  }

  /// Kullanıcının kişisel oda-aktivite kanalına abone olur.
  /// Yeni mesaj gelen oda (yeni konuşma dahil) için roomId döner.
  void subscribeUserRooms(String userId, void Function(String roomId) onActivity) {
    if (_userRoomsSub != null) return; // zaten abone
    _userRoomsSub = _client?.subscribe(
      destination: '/topic/user.$userId.rooms',
      callback: (frame) {
        if (frame.body == null) return;
        final data = jsonDecode(frame.body!) as Map<String, dynamic>;
        final roomId = data['roomId'] as String?;
        if (roomId != null) onActivity(roomId);
      },
    );
  }

  /// Register handlers for a room. Creates the STOMP subscription on first call;
  /// subsequent calls for the same room just add handlers.
  void subscribeToRoom(
    String roomId, {
    MessageCallback? onMessage,
    TypingCallback? onTyping,
    PresenceCallback? onPresence,
  }) {
    if (onMessage != null) {
      (_messageHandlers[roomId] ??= []).add(onMessage);
    }
    if (onTyping != null) {
      (_typingHandlers[roomId] ??= []).add(onTyping);
    }

    // STOMP subscription already exists — handlers registered above, done.
    if (_subscriptions.containsKey(roomId)) return;

    final subs = <StompUnsubscribe>[];

    subs.add(_client!.subscribe(
      destination: '/topic/room.$roomId',
      callback: (frame) {
        if (frame.body == null) return;
        final msg = Message.fromJson(jsonDecode(frame.body!));
        for (final h in List.of(_messageHandlers[roomId] ?? [])) {
          h(msg);
        }
      },
    ));

    subs.add(_client!.subscribe(
      destination: '/topic/room.$roomId.typing',
      callback: (frame) {
        if (frame.body == null) return;
        final data = jsonDecode(frame.body!) as Map<String, dynamic>;
        for (final h in List.of(_typingHandlers[roomId] ?? [])) {
          h(data['userId'] as String, data['typing'] as bool);
        }
      },
    ));

    subs.add(_client!.subscribe(
      destination: '/topic/room.$roomId.presence',
      callback: (frame) {},
    ));

    _subscriptions[roomId] = subs;
  }

  /// Remove specific handlers for a room. Tears down the STOMP subscription
  /// only when no handlers remain for that room.
  void unsubscribeFromRoom(
    String roomId, {
    MessageCallback? onMessage,
    TypingCallback? onTyping,
  }) {
    if (onMessage != null) _messageHandlers[roomId]?.remove(onMessage);
    if (onTyping != null) _typingHandlers[roomId]?.remove(onTyping);

    final noHandlers = (_messageHandlers[roomId]?.isEmpty ?? true) &&
        (_typingHandlers[roomId]?.isEmpty ?? true);

    if (noHandlers) {
      _subscriptions[roomId]?.forEach((u) => u());
      _subscriptions.remove(roomId);
      _messageHandlers.remove(roomId);
      _typingHandlers.remove(roomId);
    }
  }

  void sendMessage(String roomId, String content, {String? replyTo}) {
    _client?.send(
      destination: '/app/room.$roomId.send',
      body: jsonEncode({
        'type': 'TEXT',
        'content': content,
        if (replyTo != null) 'replyTo': replyTo,
      }),
    );
  }

  void sendTyping(String roomId, bool typing) {
    _client?.send(
      destination: '/app/room.$roomId.typing',
      body: jsonEncode({'typing': typing}),
    );
  }

  void sendReaction(String roomId, String messageId, String emoji) {
    _client?.send(
      destination: '/app/room.$roomId.reaction',
      body: jsonEncode({'messageId': messageId, 'emoji': emoji}),
    );
  }

  void sendReadReceipt(String roomId, String messageId) {
    _client?.send(
      destination: '/app/room.$roomId.read',
      body: jsonEncode(messageId),
    );
  }

  bool get isConnected => _client?.connected ?? false;
}
