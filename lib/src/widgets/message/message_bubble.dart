import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/chat_theme.dart';
import '../../models/message.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final bool isMe;
  final String currentUserId;
  final Message? replyToMessage;
  final void Function(Message) onReply;
  final void Function(Message, String) onReact;
  final void Function(String messageId)? onReplyTap;
  final void Function(Message)? onEdit;
  final void Function(Message)? onDelete;
  final String serverUrl;

  /// If false, the sender avatar circle on the left side of incoming messages
  /// is hidden (useful for 1-1 direct chats where the sender is obvious).
  final bool showSenderAvatar;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.currentUserId,
    this.replyToMessage,
    required this.onReply,
    required this.onReact,
    this.onReplyTap,
    this.onEdit,
    this.onDelete,
    this.serverUrl = '',
    this.showSenderAvatar = true,
  });

  @override
  State<MessageBubble> createState() => MessageBubbleState();
}

class MessageBubbleState extends State<MessageBubble> {
  bool _highlighted = false;

  /// Called externally (via GlobalKey) after scroll to flash the bubble.
  void highlight() async {
    if (!mounted) return;
    setState(() => _highlighted = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => _highlighted = false);
  }

  @override
  Widget build(BuildContext context) {
    final hasReactions = widget.message.reactions.isNotEmpty;
    final t = context.chatTheme;

    return GestureDetector(
      onLongPress: () => _showActions(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _highlighted
              ? t.primaryColor.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: widget.isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!widget.isMe && widget.showSenderAvatar) ...[
              CircleAvatar(
                radius: 14,
                backgroundColor: t.inputColor,
                child: Icon(Icons.person, size: 14, color: t.textMutedColor),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: widget.isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: EdgeInsets.only(
                          left: 12,
                          right: 12,
                          top: 8,
                          bottom: hasReactions ? 18 : 8,
                        ),
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width * 0.72,
                        ),
                        decoration: BoxDecoration(
                          color: widget.isMe
                              ? t.myBubbleColor
                              : t.otherBubbleColor,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft:
                                Radius.circular(widget.isMe ? 16 : 4),
                            bottomRight:
                                Radius.circular(widget.isMe ? 4 : 16),
                          ),
                        ),
                        child: _buildContent(context),
                      ),
                      if (hasReactions)
                        Positioned(
                          bottom: -10,
                          right: widget.isMe ? 8 : null,
                          left: widget.isMe ? null : 8,
                          child: _ReactionsRow(
                            reactions: widget.message.reactions,
                            currentUserId: widget.currentUserId,
                            onTap: (emoji) =>
                                widget.onReact(widget.message, emoji),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: hasReactions ? 14 : 2),
                  Text(
                    _formatTime(widget.message.createdAt),
                    style: TextStyle(color: t.textMutedColor, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final t = context.chatTheme;
    if (widget.message.isDeleted) {
      return Text(
        'Bu mesaj silindi',
        style: TextStyle(
            color: t.textMutedColor,
            fontStyle: FontStyle.italic,
            fontSize: 14),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.replyToMessage != null)
          GestureDetector(
            onTap: () => widget.onReplyTap?.call(widget.replyToMessage!.id),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: t.scaffoldColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border(
                    left: BorderSide(color: t.primaryColor, width: 3)),
              ),
              child: Text(
                widget.replyToMessage!.isDeleted
                    ? 'Bu mesaj silindi'
                    : widget.replyToMessage!.type == MessageType.image
                        ? '📷 Fotoğraf'
                        : (widget.replyToMessage!.content ?? ''),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: t.iconColor, fontSize: 12),
              ),
            ),
          ),
        if (widget.message.type == MessageType.text)
          _LinkText(
            text: widget.message.content ?? '',
            style: TextStyle(color: t.textColor, fontSize: 15),
            linkColor: t.primaryColor,
          ),
        if (widget.message.type == MessageType.image &&
            widget.message.imageUrl != null) ...[
          GestureDetector(
            onTap: () => _openFullScreen(context, _resolveUrl(widget.message.imageUrl!)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: _resolveUrl(widget.message.imageUrl!),
                width: 220,
                fit: BoxFit.cover,
                placeholder: (_, __) => SizedBox(
                  width: 220,
                  height: 140,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2, color: t.primaryColor),
                  ),
                ),
                errorWidget: (_, __, ___) => SizedBox(
                  width: 220,
                  height: 80,
                  child: Center(
                    child: Icon(Icons.broken_image, color: t.textMutedColor, size: 32),
                  ),
                ),
              ),
            ),
          ),
          if (widget.message.content != null && widget.message.content!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _LinkText(
                text: widget.message.content!,
                style: TextStyle(color: t.textColor, fontSize: 15),
                linkColor: t.primaryColor,
              ),
            ),
        ],
        if (widget.message.isEdited)
          Text(
            'düzenlendi',
            style: TextStyle(color: t.textMutedColor, fontSize: 10),
          ),
      ],
    );
  }

  void _showActions(BuildContext context) {
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
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: t.textMutedColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              _EmojiPicker(
                currentReactions: widget.message.reactions,
                currentUserId: widget.currentUserId,
                onSelect: (e) {
                  Navigator.pop(context);
                  widget.onReact(widget.message, e);
                },
              ),
              Divider(color: t.dividerColor, height: 1),
              ListTile(
                leading: Icon(Icons.reply, color: t.iconColor),
                title: Text('Yanıtla', style: TextStyle(color: t.textColor)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onReply(widget.message);
                },
              ),
              if (widget.message.content != null && !widget.message.isDeleted)
                ListTile(
                  leading: Icon(Icons.copy, color: t.iconColor),
                  title: Text('Kopyala', style: TextStyle(color: t.textColor)),
                  onTap: () {
                    Navigator.pop(context);
                    Clipboard.setData(ClipboardData(text: widget.message.content!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Mesaj kopyalandı'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              if (widget.isMe && !widget.message.isDeleted &&
                  widget.message.type == MessageType.text)
                ListTile(
                  leading: Icon(Icons.edit_outlined, color: t.iconColor),
                  title: Text('Düzenle', style: TextStyle(color: t.textColor)),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onEdit?.call(widget.message);
                  },
                ),
              if (widget.isMe && !widget.message.isDeleted)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('Sil', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onDelete?.call(widget.message);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _resolveUrl(String url) =>
      url.startsWith('http') ? url : '${widget.serverUrl}$url';

  void _openFullScreen(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, __, ___) => _FullScreenImage(imageUrl: imageUrl),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _EmojiPicker extends StatelessWidget {
  final List<MessageReaction> currentReactions;
  final String currentUserId;
  final void Function(String) onSelect;

  const _EmojiPicker({
    required this.currentReactions,
    required this.currentUserId,
    required this.onSelect,
  });

  static const _emojis = ['👍', '❤️', '😂', '😮', '😢', '🔥'];

  bool _isSelected(String emoji) => currentReactions
      .any((r) => r.emoji == emoji && r.userIds.contains(currentUserId));

  @override
  Widget build(BuildContext context) {
    final t = context.chatTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _emojis.map((e) {
          final selected = _isSelected(e);
          return GestureDetector(
            onTap: () => onSelect(e),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected
                    ? t.primaryColor.withValues(alpha: 0.25)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? t.primaryColor : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Text(e, style: const TextStyle(fontSize: 28)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ReactionsRow extends StatelessWidget {
  final List<MessageReaction> reactions;
  final String currentUserId;
  final void Function(String) onTap;

  const _ReactionsRow({
    required this.reactions,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.chatTheme;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: reactions.map((r) {
        final iReacted = r.userIds.contains(currentUserId);
        return GestureDetector(
          onTap: () => onTap(r.emoji),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: iReacted
                  ? t.primaryColor.withValues(alpha: 0.2)
                  : t.inputColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: iReacted ? t.primaryColor : t.dividerColor,
                width: 1,
              ),
            ),
            child: Text(
              '${r.emoji} ${r.userIds.length}',
              style: TextStyle(
                fontSize: 12,
                color: iReacted ? t.textColor : t.iconColor,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LinkText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Color linkColor;
  const _LinkText({required this.text, required this.style, required this.linkColor});

  @override
  State<_LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<_LinkText> {
  final _recognizers = <TapGestureRecognizer>[];

  static final _urlRegex = RegExp(
    r'https?://[^\s]+',
    caseSensitive: false,
  );

  @override
  void dispose() {
    for (final r in _recognizers) r.dispose();
    super.dispose();
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) r.dispose();
    _recognizers.clear();

    final spans = <InlineSpan>[];
    int last = 0;

    for (final match in _urlRegex.allMatches(widget.text)) {
      if (match.start > last) {
        spans.add(TextSpan(
          text: widget.text.substring(last, match.start),
          style: widget.style,
        ));
      }
      final url = match.group(0)!;
      final rec = TapGestureRecognizer()..onTap = () => _open(url);
      _recognizers.add(rec);
      spans.add(TextSpan(
        text: url,
        recognizer: rec,
        style: widget.style.copyWith(
          color: widget.linkColor,
          decoration: TextDecoration.underline,
          decorationColor: widget.linkColor,
        ),
      ));
      last = match.end;
    }

    if (last < widget.text.length) {
      spans.add(TextSpan(
        text: widget.text.substring(last),
        style: widget.style,
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }
}

class _FullScreenImage extends StatelessWidget {
  final String imageUrl;
  const _FullScreenImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: InteractiveViewer(
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (_, __) =>
                  const CircularProgressIndicator(color: Colors.white),
              errorWidget: (_, __, ___) =>
                  const Icon(Icons.broken_image, color: Colors.white54, size: 64),
            ),
          ),
        ),
      ),
    );
  }
}
