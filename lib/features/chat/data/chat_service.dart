import '../models/chat_message.dart';

class SuggestedTask {
  const SuggestedTask({required this.title, required this.details});

  final String title;
  final String details;
}

class ChatReply {
  const ChatReply({required this.text, this.tasks = const []});

  final String text;
  final List<SuggestedTask> tasks;
}

class ChatReplyException implements Exception {
  const ChatReplyException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class ChatService {
  Future<String> reply(List<ChatMessage> conversation);

  // Services without task-generation support can use this default.
  Future<ChatReply> generateReply(
    List<ChatMessage> conversation, {
    required bool allowTasks,
    String context = '',
  }) async {
    return ChatReply(text: await reply(conversation));
  }
}
