import '../../../features/chat/models/chat_message.dart';
import 'chat_service.dart';

class MockChatService extends ChatService {
  @override
  Future<String> reply(List<ChatMessage> conversation) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    return 'This is a simulated reply. Your message was: '
        '"${conversation.last.text}". The AI connection will be added later.';
  }
}
