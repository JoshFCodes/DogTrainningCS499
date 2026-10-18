import 'package:flutter/material.dart';

class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.enabled,
    required this.onSend,
  });
  final bool enabled;
  final ValueChanged<String> onSend;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final _text = TextEditingController();

  void _send() {
    final value = _text.text.trim();
    if (!widget.enabled || value.isEmpty) return;
    _text.clear();
    widget.onSend(value);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _text,
            minLines: 1,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(hintText: 'Write a message...'),
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _text,
          builder: (context, value, child) => IconButton.filled(
            tooltip: 'Send message',
            onPressed: widget.enabled && value.text.trim().isNotEmpty
                ? _send
                : null,
            icon: const Icon(Icons.arrow_upward),
          ),
        ),
      ],
    ),
  );
}
