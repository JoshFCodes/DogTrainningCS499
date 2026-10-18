import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/chat_repository.dart';
import '../data/chat_service.dart';
import 'chat_controller.dart';
import 'widgets/message_bubble.dart';
import 'widgets/message_composer.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.service, this.sessionId});

  final ChatService service;
  final String? sessionId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatController _chat;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser!;

    _chat = ChatController(
      widget.service,
      ChatRepository(user.uid),
      sessionId: widget.sessionId,
    );

    _chat.initialize();
  }

  @override
  void dispose() {
    _chat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _chat,
      builder: (context, child) {
        final messages = _chat.messages;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              _chat.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Lenbo • Powered by Gemini'),
                    ),
                    Expanded(
                      child: !_chat.isReady
                          ? Center(
                              child: _chat.isSending
                                  ? const CircularProgressIndicator()
                                  : const Text('Conversation not loaded.'),
                            )
                          : messages.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'Start a conversation by sending '
                                  'a message.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : ListView.builder(
                              reverse: true,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: messages.length,
                              itemBuilder: (context, index) => MessageBubble(
                                message: messages[messages.length - 1 - index],
                              ),
                            ),
                    ),
                    if (_chat.isSending && _chat.isReady)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Text('Working on your conversation...'),
                          ],
                        ),
                      ),
                    if (_chat.error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            Text(_chat.error!, textAlign: TextAlign.center),
                            TextButton(
                              onPressed: _chat.isSending ? null : _chat.retry,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    MessageComposer(enabled: _chat.canSend, onSend: _chat.send),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
