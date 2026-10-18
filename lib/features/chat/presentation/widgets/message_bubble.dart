import 'package:flutter/material.dart';

import '../../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * .85),
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isUser ? colors.primary : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUser ? 'You' : 'Assistant',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isUser ? colors.onPrimary : colors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  message.text,
                  style: TextStyle(
                    color: isUser ? colors.onPrimary : colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
