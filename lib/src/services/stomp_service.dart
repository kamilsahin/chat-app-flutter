import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  // Kullanıcının kişisel oda-aktivite kanalı için callback (reconnect'te yeniden abone olmak için)
  String? _userRoomsUserId;
  void Function(String roomId)? _userRoomsCallback;
  StompUnsubscribe? _userRoomsSub;

  // Callbacks waiting for the first successful connect.
  // Cleared after first connect; reconnects only call _resubscribeAll().
  final List<VoidCallback> _pendingConnectCallbacks = [];

  StompService(this._config);

  void connect({required VoidCallback onConnected}) {
    // Already connected — call onConnected immediately.
    if (_client?.connected ?? false) {
      onConnected();
      return;
    }

    // Queue the callback; it will be called when the connection succeeds.
    _pendingConnectCallbacks.add(onConnected);

    // Client is already activating (not yet connected) — just wait.
    if (_client != null) return;

    // Deactivate any stale client before creating a new one.
    _subscriptions.clear();
    _userRoomsSub = null;

    debugPrint('[STOMP] Bağlanıyor → ${_config.serverUrl}/ws');
    _client = StompClient(
      config: StompConfig.sockJS(
        url: '${_config.serverUrl}/ws',
        stompConnectHeaders: {
          'Authorization': 'Bearer ${_config.jwtToken}',
        },
        onConnect: _handleConnected,
        onDisconnect: _handleDisconnected,
        onStompError: (frame) => debugPrint('[STOMP] STOMP hata: ${frame.body}'),
        onWebSocketError: (e) => debugPrint('[STOMP] WebSocket hata: $e'),
        onWebSocketDone: () => debugPrint('[STOMP] WebSocket kapandı'),
        reconnectDelay: const Duration(seconds: 5),
      ),
    );
    _client!.activate();
  }

  void _handleConnected(StompFrame frame) {
    debugPrint('[STOMP] ✓ Bağlandı — aktif oda sayısı: ${_messageHandlers.length}');
    _resubscribeAll();
    // Drain pending callbacks (first connect only; reconnects skip this).
    final callbacks = List.of(_pendingConnectCallbacks);
    _pendingConnectCallbacks.clear();
    for (final cb in callbacks) cb();
  }

  void _handleDisconnected(StompFrame frame) {
    debugPrint('[STOMP] ✗ Bağlantı koptu — ${_subscriptions.length} subscription temizlendi');
    // Subscription references are now invalid. Clear them so subscribeToRoom()
    // will create fresh ones when the client reconnects.
    _subscriptions.clear();
    _userRoomsSub = null;
  }

  /// Re-opens STOMP subscriptions for all rooms that have active handlers.
  /// Called on every (re)connect so no messages are missed after a drop.
  void _resubscribeAll() {
    debugPrint('[STOMP] _resubscribeAll → ${_messageHandlers.length} oda');
    for (final roomId in _messageHandlers.keys.toList()) {
      _openRoomSubscription(roomId);
    }
    // Re-subscribe to the user-rooms channel if it was active.
    if (_userRoomsUserId != null && _userRoomsCallback != null) {
      _userRoomsSub = null; // ensure it's recreated
      _openUserRoomsSubscription(_userRoomsUserId!, _userRoomsCallback!);
    }
  }

  void _openRoomSubscription(String roomId) {
    if (_subscriptions.containsKey(roomId)) return;
    debugPrint('[STOMP] Subscribe → room.$roomId (handlers: ${_messageHandlers[roomId]?.length ?? 0})');

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

  void _openUserRoomsSubscription(String userId, void Function(String roomId) onActivity) {
    if (_userRoomsSub != null) return;
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

  void disconnect() {
    _client?.deactivate();
    _client = null;
    _subscriptions.clear();
    _messageHandlers.clear();
    _typingHandlers.clear();
    _pendingConnectCallbacks.clear();
    _userRoomsSub = null;
    _userRoomsUserId = null;
    _userRoomsCallback = null;
  }

  /// Kullanıcının kişisel oda-aktivite kanalına abone olur.
  /// Yeni mesaj gelen oda (yeni konuşma dahil) için roomId döner.
  void subscribeUserRooms(String userId, void Function(String roomId) onActivity) {
    _userRoomsUserId = userId;
    _userRoomsCallback = onActivity;
    _openUserRoomsSubscription(userId, onActivity);
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

    _openRoomSubscription(roomId);
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
