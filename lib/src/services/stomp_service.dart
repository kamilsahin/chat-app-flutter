import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../config/chat_config.dart';
import '../models/message.dart';

typedef MessageCallback = void Function(Message message);
typedef TypingCallback = void Function(String userId, bool typing);
typedef PresenceCallback = void Function(String userId, bool online);

class StompService {
  final ChatConfig _config;
  StompClient? _client;

  final Map<String, List<StompUnsubscribe>> _subscriptions = {};

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
        onStompError: (frame) {},
        onWebSocketError: (error) {},
      ),
    );
    _client!.activate();
  }

  void disconnect() {
    _client?.deactivate();
    _subscriptions.clear();
  }

  void subscribeToRoom(
    String roomId, {
    required MessageCallback onMessage,
    required TypingCallback onTyping,
    required PresenceCallback onPresence,
  }) {
    final subs = <StompUnsubscribe>[];

    subs.add(_client!.subscribe(
      destination: '/topic/room.$roomId',
      callback: (frame) {
        if (frame.body == null) return;
        final msg = Message.fromJson(jsonDecode(frame.body!));
        onMessage(msg);
      },
    ));

    subs.add(_client!.subscribe(
      destination: '/topic/room.$roomId.typing',
      callback: (frame) {
        if (frame.body == null) return;
        final data = jsonDecode(frame.body!) as Map<String, dynamic>;
        onTyping(data['userId'] as String, data['typing'] as bool);
      },
    ));

    subs.add(_client!.subscribe(
      destination: '/topic/room.$roomId.presence',
      callback: (frame) {
        if (frame.body == null) return;
        final data = jsonDecode(frame.body!) as Map<String, dynamic>;
        onPresence(data['userId'] as String, data['online'] as bool);
      },
    ));

    _subscriptions[roomId] = subs;
  }

  void unsubscribeFromRoom(String roomId) {
    _subscriptions[roomId]?.forEach((unsub) => unsub());
    _subscriptions.remove(roomId);
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

typedef VoidCallback = void Function();
