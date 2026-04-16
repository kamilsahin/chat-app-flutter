import 'package:flutter/material.dart';
import '../../models/message.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final bool isMe;
  final String currentUserId;
  final Message? replyToMessage;
  final void Function(Message) onReply;
  final void Function(Message, String) onReact;
  final void Function(String messageId)? onReplyTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.currentUserId,
    this.replyToMessage,
    required this.onReply,
    required this.onReact,
    this.onReplyTap,
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

    return GestureDetector(
      onLongPress: () => _showActions(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _highlighted
              ? const Color(0xFF4CAF50).withValues(alpha: 0.12)
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
            if (!widget.isMe) ...[
              const CircleAvatar(
                radius: 14,
                backgroundColor: Color(0xFF2A2A2A),
                child: Icon(Icons.person, size: 14, color: Colors.white54),
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
                              ? const Color(0xFF2A5C3F)
                              : const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft:
                                Radius.circular(widget.isMe ? 16 : 4),
                            bottomRight:
                                Radius.circular(widget.isMe ? 4 : 16),
                          ),
                        ),
                        child: _buildContent(),
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
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (widget.message.isDeleted) {
      return const Text(
        'Bu mesaj silindi',
        style: TextStyle(
            color: Colors.white38,
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
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: const Border(
                    left:
                        BorderSide(color: Color(0xFF4CAF50), width: 3)),
              ),
              child: Text(
                widget.replyToMessage!.isDeleted
                    ? 'Bu mesaj silindi'
                    : (widget.replyToMessage!.content ?? ''),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ),
          ),
        if (widget.message.type == MessageType.text)
          Text(
            widget.message.content ?? '',
            style:
                const TextStyle(color: Colors.white, fontSize: 15),
          ),
        if (widget.message.type == MessageType.image &&
            widget.message.imageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(widget.message.imageUrl!, width: 200),
          ),
        if (widget.message.isEdited)
          const Text(
            'düzenlendi',
            style: TextStyle(color: Colors.white38, fontSize: 10),
          ),
      ],
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet(
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
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
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
            const Divider(color: Color(0xFF2A2A2A), height: 1),
            ListTile(
              leading: const Icon(Icons.reply, color: Colors.white70),
              title: const Text('Yanıtla',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                widget.onReply(widget.message);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
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
                    ? const Color(0xFF4CAF50).withValues(alpha: 0.25)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? const Color(0xFF4CAF50)
                      : Colors.transparent,
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
                  ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                  : const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: iReacted
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFF3A3A3A),
                width: 1,
              ),
            ),
            child: Text(
              '${r.emoji} ${r.userIds.length}',
              style: TextStyle(
                fontSize: 12,
                color: iReacted ? Colors.white : Colors.white70,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
