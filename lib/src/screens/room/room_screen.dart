import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/message.dart';
import '../../providers/config_provider.dart';
import '../../providers/room_providers.dart';
import '../../providers/service_providers.dart';
import '../../widgets/message/message_bubble.dart';

class RoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  const RoomScreen({super.key, required this.roomId});

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  Message? _replyingTo;
  Timer? _typingTimer;
  bool _isTyping = false;
  // ref is already invalid when dispose() is called (Riverpod unmounts ref
  // before calling super.unmount → state.dispose). Store the container
  // directly so we can clear activeRoomProvider safely in dispose().
  late ProviderContainer _container;

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _container.read(activeRoomProvider.notifier).state = widget.roomId;
      }
    });
  }

  @override
  void dispose() {
    _container.read(activeRoomProvider.notifier).state = null;
    _controller.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    ref.read(stompServiceProvider).sendMessage(
          widget.roomId,
          text,
          replyTo: _replyingTo?.id,
        );

    _controller.clear();
    setState(() => _replyingTo = null);
    _stopTyping();
  }

  void _onTextChanged(String text) {
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      ref.read(stompServiceProvider).sendTyping(widget.roomId, true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), _stopTyping);
  }

  void _stopTyping() {
    if (_isTyping) {
      _isTyping = false;
      ref.read(stompServiceProvider).sendTyping(widget.roomId, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messageListProvider(widget.roomId));
    final typingUsers = ref.watch(typingProvider(widget.roomId));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sohbet', style: TextStyle(color: Colors.white)),
            if (typingUsers.isNotEmpty)
              Text(
                'yazıyor...',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(e.toString(),
                    style: const TextStyle(color: Colors.white70)),
              ),
              data: (messages) => ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                itemCount: messages.length,
                itemBuilder: (context, i) {
                  final msg = messages[i];
                  final isMe = msg.senderId ==
                      ref.read(chatConfigProvider).jwtToken;
                  return MessageBubble(
                    message: msg,
                    isMe: isMe,
                    onReply: (m) => setState(() => _replyingTo = m),
                    onReact: (m, emoji) => ref
                        .read(stompServiceProvider)
                        .sendReaction(widget.roomId, m.id, emoji),
                  );
                },
              ),
            ),
          ),
          if (_replyingTo != null) _ReplyBar(
            message: _replyingTo!,
            onCancel: () => setState(() => _replyingTo = null),
          ),
          _InputBar(
            controller: _controller,
            onChanged: _onTextChanged,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class _ReplyBar extends StatelessWidget {
  final Message message;
  final VoidCallback onCancel;
  const _ReplyBar({required this.message, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(width: 3, height: 36, color: const Color(0xFF4CAF50)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.content ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 18),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.onChanged,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                onSubmitted: (_) => onSend(),
                style: const TextStyle(color: Colors.white),
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Mesaj yaz...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: const Color(0xFF4CAF50),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 18),
                onPressed: onSend,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
