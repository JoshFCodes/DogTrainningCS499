enum MessageRole { user, assistant }

class ChatMessage {
  const ChatMessage({required this.role, required this.text});

  final MessageRole role;
  final String text;
}
