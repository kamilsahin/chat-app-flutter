import 'package:flutter/material.dart';
import '../../models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final void Function(Message) onReply;
  final void Function(Message, String) onReact;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
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
                    _ReactionsRow(reactions: message.reactions),
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
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EmojiRow(onSelect: (e) {
            Navigator.pop(context);
            onReact(message, e);
          }),
          ListTile(
            leading: const Icon(Icons.reply, color: Colors.white70),
            title: const Text('Yanıtla',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              onReply(message);
            },
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _EmojiRow extends StatelessWidget {
  final void Function(String) onSelect;
  const _EmojiRow({required this.onSelect});

  static const emojis = ['👍', '❤️', '😂', '😮', '😢', '🔥'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: emojis
            .map((e) => GestureDetector(
                  onTap: () => onSelect(e),
                  child: Text(e, style: const TextStyle(fontSize: 28)),
                ))
            .toList(),
      ),
    );
  }
}

class _ReactionsRow extends StatelessWidget {
  final List<MessageReaction> reactions;
  const _ReactionsRow({required this.reactions});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        children: reactions.map((r) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${r.emoji} ${r.userIds.length}',
              style: const TextStyle(fontSize: 12),
            ),
          );
        }).toList(),
      ),
    );
  }
}
