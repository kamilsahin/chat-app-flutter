import 'package:flutter/material.dart';
import '../../models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String currentUserId;
  final void Function(Message) onReply;
  final void Function(Message, String) onReact;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.currentUserId,
    required this.onReply,
    required this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showActions(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              const CircleAvatar(
                radius: 14,
                backgroundColor: Color(0xFF2A2A2A),
                child: Icon(Icons.person, size: 14, color: Colors.white54),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? const Color(0xFF2A5C3F)
                          : const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                    ),
                    child: _buildContent(),
                  ),
                  if (message.reactions.isNotEmpty)
                    _ReactionsRow(
                      reactions: message.reactions,
                      currentUserId: currentUserId,
                      onTap: (emoji) => onReact(message, emoji),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(message.createdAt),
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
    if (message.isDeleted) {
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
        if (message.replyTo != null)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
              border: const Border(
                  left: BorderSide(color: Color(0xFF4CAF50), width: 3)),
            ),
            child: const Text(
              'Yanıtlanan mesaj',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        if (message.type == MessageType.text)
          Text(
            message.content ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        if (message.type == MessageType.image && message.imageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(message.imageUrl!, width: 200),
          ),
        if (message.isEdited)
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
              currentReactions: message.reactions,
              currentUserId: currentUserId,
              onSelect: (e) {
                Navigator.pop(context);
                onReact(message, e);
              },
            ),
            const Divider(color: Color(0xFF2A2A2A), height: 1),
            ListTile(
              leading: const Icon(Icons.reply, color: Colors.white70),
              title: const Text('Yanıtla',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                onReply(message);
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

// ---------------------------------------------------------------------------
// Emoji picker shown in the bottom sheet
// ---------------------------------------------------------------------------
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

  bool _iSelected(String emoji) {
    return currentReactions
        .any((r) => r.emoji == emoji && r.userIds.contains(currentUserId));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _emojis.map((e) {
          final selected = _iSelected(e);
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

// ---------------------------------------------------------------------------
// Reaction chips shown below the message bubble
// ---------------------------------------------------------------------------
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
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: reactions.map((r) {
          final iReacted = r.userIds.contains(currentUserId);
          return GestureDetector(
            onTap: () => onTap(r.emoji),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: iReacted
                    ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                    : const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: iReacted
                      ? const Color(0xFF4CAF50)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Text(
                '${r.emoji} ${r.userIds.length}',
                style: TextStyle(
                  fontSize: 13,
                  color: iReacted ? Colors.white : Colors.white70,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
