import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/chat_theme.dart';
import '../../models/message.dart';
import '../../models/room.dart';
import '../../providers/config_provider.dart';
import '../../providers/room_providers.dart';
import '../../providers/service_providers.dart';
import '../../services/stomp_service.dart';
import '../../widgets/message/message_bubble.dart';

class RoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String? title;
  final RoomType? typeFilter;

  /// Type of the room — used to hide sender avatars in direct chats and to
  /// show the other person's photo in the app bar.
  final RoomType? roomType;

  /// Avatar URL of the room (other person's photo for direct, group photo for groups).
  final String? avatarUrl;

  const RoomScreen({
    super.key,
    required this.roomId,
    this.title,
    this.typeFilter,
    this.roomType,
    this.avatarUrl,
  });

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
  ProviderContainer? _container;
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
      _container
          ?.read(messageListProvider(widget.roomId).notifier)
          .addMessage(message);
    };
    _onTyping = (userId, typing) {
      _container
          ?.read(typingProvider(widget.roomId).notifier)
          .setTyping(userId, typing);
    };

    // Register after the first frame so messageListProvider is already
    // being watched (and therefore initialized) by build().
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _container
            ?.read(stompServiceProvider)
            .subscribeToRoom(
              widget.roomId,
              onMessage: _onMessage,
              onTyping: _onTyping,
            );
        _container?.read(activeRoomProvider.notifier).state = widget.roomId;
        _container
            ?.read(roomListProvider(widget.typeFilter).notifier)
            .clearUnread(widget.roomId);
        // Mark all messages as read on the backend so the next room-list
        // fetch reflects the correct unread count.
        _container?.read(apiServiceProvider).markRoomAsRead(widget.roomId).ignore();
      }
    });
  }

  @override
  void dispose() {
    // Unregister our handlers. Because Dart is single-threaded, no STOMP event
    // can fire between this removal and super.dispose() marking the element
    // defunct — so addMessage will never be called on a defunct element.
    _container
        ?.read(stompServiceProvider)
        .unsubscribeFromRoom(
          widget.roomId,
          onMessage: _onMessage,
          onTyping: _onTyping,
        );
    // Delay provider mutations — dispose() is called during tree finalization
    // (lockState), and Riverpod forbids state changes in that window.
    // Capture before nulling so the microtask closure can use it safely.
    final container = _container;
    _container = null;
    Future.microtask(() {
      container?.read(activeRoomProvider.notifier).state = null;
      container
          ?.read(roomListProvider(widget.typeFilter).notifier)
          .clearUnread(widget.roomId);
    });
    _controller.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    ref
        .read(stompServiceProvider)
        .sendMessage(widget.roomId, text, replyTo: _replyingTo?.id);

    _controller.clear();
    setState(() => _replyingTo = null);
    _stopTyping();
    _scrollToBottom();
  }

  Future<void> _editMessage(Message message) async {
    final controller = TextEditingController(text: message.content);
    final t = context.chatTheme;
    final newContent = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.appBarColor,
        title: Text('Mesajı Düzenle', style: TextStyle(color: t.textColor)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: t.textColor),
          maxLines: null,
          decoration: InputDecoration(
            filled: true,
            fillColor: t.inputColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: TextStyle(color: t.textMutedColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('Kaydet', style: TextStyle(color: t.primaryColor)),
          ),
        ],
      ),
    );
    if (newContent == null ||
        newContent.isEmpty ||
        newContent == message.content) {
      return;
    }
    try {
      final updated = await ref
          .read(apiServiceProvider)
          .editMessage(message.id, newContent);
      ref
          .read(messageListProvider(widget.roomId).notifier)
          .updateMessage(updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Mesaj düzenlenemedi')));
      }
    }
  }

  Future<void> _deleteMessage(Message message) async {
    final t = context.chatTheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.appBarColor,
        title: Text('Mesajı Sil', style: TextStyle(color: t.textColor)),
        content: Text(
          'Bu mesajı silmek istiyor musunuz?',
          style: TextStyle(color: t.textMutedColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('İptal', style: TextStyle(color: t.textMutedColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final updated = await ref
          .read(apiServiceProvider)
          .deleteMessage(message.id);
      ref
          .read(messageListProvider(widget.roomId).notifier)
          .updateMessage(updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Mesaj silinemedi')));
      }
    }
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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
      // Use _container instead of ref — this may be called from a Timer
      // callback after the widget is disposed, when ref is no longer valid.
      _container?.read(stompServiceProvider).sendTyping(widget.roomId, false);
    }
  }

  Future<void> _pickAndSendImage() async {
    final t = context.chatTheme;
    final source = await showModalBottomSheet<ImageSource>(
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
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: t.textMutedColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: t.iconColor),
                title: Text(
                  'Galeriden seç',
                  style: TextStyle(color: t.textColor),
                ),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: Icon(Icons.camera_alt, color: t.iconColor),
                title: Text('Kamera', style: TextStyle(color: t.textColor)),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final message = await ref
          .read(apiServiceProvider)
          .sendImageMessage(widget.roomId, picked.path, mimeType: picked.mimeType);
      // Add directly from REST response — don't wait for STOMP broadcast.
      // addMessage does upsert so no duplicate if STOMP also delivers it.
      _container
          .read(messageListProvider(widget.roomId).notifier)
          .addMessage(message);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Fotoğraf gönderilemedi')));
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
      final target = (idx * estimatedItemHeight).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
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
    final config = ref.read(chatConfigProvider);

    final t = context.chatTheme;
    final isDirect = widget.roomType == RoomType.direct;

    return Scaffold(
      backgroundColor: t.scaffoldColor,
      appBar: AppBar(
        backgroundColor: t.appBarColor,
        titleSpacing: isDirect ? 0 : NavigationToolbar.kMiddleSpacing,
        title: Row(
          children: [
            if (isDirect) ...[
              _AppBarAvatar(
                avatarUrl: widget.avatarUrl,
                serverUrl: config.apiUrl,
              ),
              const SizedBox(width: 10),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title ?? 'Sohbet',
                  style: TextStyle(color: t.textColor),
                ),
                if (typingUsers.isNotEmpty)
                  Text(
                    'yazıyor...',
                    style: TextStyle(color: t.textMutedColor, fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
        iconTheme: IconThemeData(color: t.textColor),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  e.toString(),
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              data: (messages) => ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemCount: messages.length,
                itemBuilder: (context, i) {
                  final msg = messages[i];
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

                  // reverse:true → i=0 newest (bottom), i=N-1 oldest (top).
                  // Show a date separator above the OLDEST message of each day.
                  // That's when this message is older-day than the next item (i+1),
                  // or when this IS the very oldest message (i == messages.length-1).
                  final showSeparator = i == messages.length - 1 ||
                      !_isSameDay(msg.createdAt, messages[i + 1].createdAt);

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showSeparator)
                        _DateSeparator(date: msg.createdAt),
                      MessageBubble(
                        key: bubbleKey,
                        message: msg,
                        isMe: isMe,
                        currentUserId: userId,
                        serverUrl: serverUrl,
                        replyToMessage: replyTo,
                        showSenderAvatar: !isDirect,
                        onReply: (m) => setState(() => _replyingTo = m),
                        onReact: (m, emoji) => ref
                            .read(stompServiceProvider)
                            .sendReaction(widget.roomId, m.id, emoji),
                        onReplyTap: _scrollToMessage,
                        onEdit: _editMessage,
                        onDelete: _deleteMessage,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          if (_replyingTo != null)
            _ReplyBar(
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
    final t = context.chatTheme;
    return Container(
      color: t.appBarColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(width: 3, height: 36, color: t.primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.content ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: t.iconColor, fontSize: 13),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: t.textMutedColor, size: 18),
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
    final t = context.chatTheme;
    return Container(
      color: t.appBarColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.image_outlined, color: t.textMutedColor),
              onPressed: uploading ? null : onImageTap,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                onSubmitted: (_) => onSend(),
                style: TextStyle(color: t.textColor),
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Mesaj yaz...',
                  hintStyle: TextStyle(color: t.textMutedColor),
                  filled: true,
                  fillColor: t.inputColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: t.primaryColor,
              child: uploading
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.textColor,
                      ),
                    )
                  : IconButton(
                      icon: Icon(Icons.send, color: t.textColor, size: 18),
                      onPressed: onSend,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final t = context.chatTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: t.dividerColor, thickness: 0.8)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: t.inputColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _label(date),
              style: TextStyle(
                color: t.textMutedColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: t.dividerColor, thickness: 0.8)),
        ],
      ),
    );
  }

  String _label(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;

    if (diff == 0) return 'Bugün';
    if (diff == 1) return 'Dün';
    if (diff < 7) {
      const days = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
      return days[date.weekday - 1];
    }
    const months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    if (date.year == now.year) {
      return '${date.day} ${months[date.month - 1]}';
    }
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

/// Small circular avatar shown in the app bar for direct (1-1) chats.
class _AppBarAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String serverUrl;

  const _AppBarAvatar({required this.avatarUrl, required this.serverUrl});

  @override
  Widget build(BuildContext context) {
    final t = context.chatTheme;

    if (avatarUrl != null) {
      final url = avatarUrl!.startsWith('http') ? avatarUrl! : '$serverUrl$avatarUrl';
      return CircleAvatar(
        radius: 18,
        backgroundColor: t.inputColor,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: url,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            placeholder: (_, __) => Icon(Icons.person, size: 18, color: t.textMutedColor),
            errorWidget: (_, __, ___) => Icon(Icons.person, size: 18, color: t.textMutedColor),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 18,
      backgroundColor: t.inputColor,
      child: Icon(Icons.person, size: 18, color: t.textMutedColor),
    );
  }
}
