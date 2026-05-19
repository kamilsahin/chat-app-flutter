import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/message.dart';
import '../../providers/config_provider.dart';
import '../../providers/room_providers.dart';
import '../../providers/service_providers.dart';
import '../../services/stomp_service.dart';
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
  bool _uploading = false;
  bool _initialized = false;
  late ProviderContainer _container;
  late MessageCallback _onMessage;
  late TypingCallback _onTyping;

  // One GlobalKey per message id — used for scroll-to + highlight
  final Map<String, GlobalKey<MessageBubbleState>> _bubbleKeys = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    // ProviderScope.containerOf uses dependOnInheritedWidgetOfExactType,
    // which must be called from didChangeDependencies, not initState.
    _container = ProviderScope.containerOf(context);

    _onMessage = (message) {
      _container.read(messageListProvider(widget.roomId).notifier).addMessage(message);
    };
    _onTyping = (userId, typing) {
      _container.read(typingProvider(widget.roomId).notifier).setTyping(userId, typing);
    };

    // Register after the first frame so messageListProvider is already
    // being watched (and therefore initialized) by build().
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _container.read(stompServiceProvider).subscribeToRoom(
          widget.roomId,
          onMessage: _onMessage,
          onTyping: _onTyping,
        );
        _container.read(activeRoomProvider.notifier).state = widget.roomId;
        _container.read(roomListProvider.notifier).clearUnread(widget.roomId);
      }
    });
  }

  @override
  void dispose() {
    // Unregister our handlers. Because Dart is single-threaded, no STOMP event
    // can fire between this removal and super.dispose() marking the element
    // defunct — so addMessage will never be called on a defunct element.
    _container.read(stompServiceProvider).unsubscribeFromRoom(
      widget.roomId,
      onMessage: _onMessage,
      onTyping: _onTyping,
    );
    _container.read(activeRoomProvider.notifier).state = null;
    _container.read(roomListProvider.notifier).clearUnread(widget.roomId);
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
    _scrollToBottom();
  }

  Future<void> _editMessage(Message message) async {
    final controller = TextEditingController(text: message.content);
    final newContent = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Mesajı Düzenle',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          maxLines: null,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Kaydet',
                style: TextStyle(color: Color(0xFF4CAF50))),
          ),
        ],
      ),
    );
    if (newContent == null || newContent.isEmpty || newContent == message.content) return;
    try {
      final updated =
          await ref.read(apiServiceProvider).editMessage(message.id, newContent);
      ref.read(messageListProvider(widget.roomId).notifier).updateMessage(updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mesaj düzenlenemedi')),
        );
      }
    }
  }

  Future<void> _deleteMessage(Message message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Mesajı Sil',
            style: TextStyle(color: Colors.white)),
        content: const Text('Bu mesajı silmek istiyor musunuz?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final updated =
          await ref.read(apiServiceProvider).deleteMessage(message.id);
      ref.read(messageListProvider(widget.roomId).notifier).updateMessage(updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mesaj silinemedi')),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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

  Future<void> _pickAndSendImage() async {
    final source = await showModalBottomSheet<ImageSource>(
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
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white70),
              title: const Text('Galeriden seç', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white70),
              title: const Text('Kamera', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final message = await ref.read(apiServiceProvider).sendImageMessage(widget.roomId, picked.path);
      // Add directly from REST response — don't wait for STOMP broadcast.
      // addMessage does upsert so no duplicate if STOMP also delivers it.
      _container.read(messageListProvider(widget.roomId).notifier).addMessage(message);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotoğraf gönderilemedi')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _scrollToMessage(String messageId) async {
    final key = _bubbleKeys[messageId];
    if (key == null) return;

    if (key.currentContext != null) {
      // Item is already built — scroll directly to it
      await Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
    } else {
      // Item not in viewport — scroll to an estimated offset and wait for it
      // to be built, then fine-tune with ensureVisible.
      final messages =
          ref.read(messageListProvider(widget.roomId)).valueOrNull ?? [];
      final idx = messages.indexWhere((m) => m.id == messageId);
      if (idx == -1) return;

      const estimatedItemHeight = 72.0;
      final target = (idx * estimatedItemHeight)
          .clamp(0.0, _scrollController.position.maxScrollExtent);
      await _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
      // Give the builder a frame to build the newly visible item
      await Future.delayed(const Duration(milliseconds: 80));
      if (key.currentContext != null) {
        await Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: 0.5,
        );
      }
    }

    key.currentState?.highlight();
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
                  final config = ref.read(chatConfigProvider);
                  final userId = config.userId;
                  final serverUrl = config.apiUrl;
                  final isMe = msg.senderId == userId;
                  final replyTo = msg.replyTo != null
                      ? messages.where((m) => m.id == msg.replyTo).firstOrNull
                      : null;
                  final bubbleKey = _bubbleKeys.putIfAbsent(
                    msg.id,
                    () => GlobalKey<MessageBubbleState>(),
                  );
                  return MessageBubble(
                    key: bubbleKey,
                    message: msg,
                    isMe: isMe,
                    currentUserId: userId,
                    serverUrl: serverUrl,
                    replyToMessage: replyTo,
                    onReply: (m) => setState(() => _replyingTo = m),
                    onReact: (m, emoji) => ref
                        .read(stompServiceProvider)
                        .sendReaction(widget.roomId, m.id, emoji),
                    onReplyTap: _scrollToMessage,
                    onEdit: _editMessage,
                    onDelete: _deleteMessage,
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
            onImageTap: _pickAndSendImage,
            uploading: _uploading,
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
  final VoidCallback onImageTap;
  final bool uploading;

  const _InputBar({
    required this.controller,
    required this.onChanged,
    required this.onSend,
    required this.onImageTap,
    required this.uploading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.image_outlined, color: Colors.white54),
              onPressed: uploading ? null : onImageTap,
            ),
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
              child: uploading
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : IconButton(
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
