import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../auth/data/auth_service.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/data/gemini_chat_service.dart';
import '../../chat/presentation/chat_screen.dart';

class SavedTrainingPanel extends StatefulWidget {
  const SavedTrainingPanel({super.key});

  @override
  State<SavedTrainingPanel> createState() => _SavedTrainingPanelState();
}

class _SavedTrainingPanelState extends State<SavedTrainingPanel> {
  late final ChatRepository _repository;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _tasks;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _sessions;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _repository = ChatRepository(AuthService.instance.currentUser!.uid);

    _tasks = _repository.watchTasks();
    _sessions = _repository.watchSessions();
  }

  Future<void> _removeConversation(String sessionId, String title) async {
    if (_busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove from previous chats?'),
        content: Text(
          '"$title" will disappear from this list. '
          'Any linked next steps will remain available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _run(() => _repository.archiveSession(sessionId));
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _orderedActiveTasks(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final groups =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};

    // The incoming query already puts the newest recommendations first.
    // Group tasks by the assistant response that generated them.
    for (final document in snapshot.docs) {
      final data = document.data();

      if (data['completed'] == true) continue;

      final groupKey = '${data['sourceSessionId']}/${data['sourceMessageId']}';

      groups.putIfAbsent(groupKey, () => []).add(document);
    }

    int stepOrder(QueryDocumentSnapshot<Map<String, dynamic>> document) {
      final storedOrder = document.data()['stepOrder'];

      if (storedOrder is int) return storedOrder;

      // Older tasks already encode their position in their document ID:
      // sessionId_messageSequence_stepIndex
      return int.tryParse(document.id.split('_').last) ?? 0;
    }

    final ordered = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    for (final group in groups.values) {
      group.sort((a, b) => stepOrder(a).compareTo(stepOrder(b)));
      ordered.addAll(group);
    }

    return ordered;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() => _error = accountErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openChat(String sessionId) async {
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ChatScreen(service: GeminiChatService(), sessionId: sessionId),
      ),
    );
  }

  Future<void> _openTask(String taskId) async {
    await _run(() async {
      final sessionId = await _repository.explanationFor(taskId);

      if (mounted) {
        await _openChat(sessionId);
      }
    });
  }

  Widget _heading(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _notice(String text) {
    return Padding(padding: const EdgeInsets.all(20), child: Text(text));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Next Steps'),
        const SizedBox(height: 8),
        const Text('Tap a task for guidance, or check it off when complete.'),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _tasks,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _notice(
                  'Unable to load next steps. Check your connection '
                  'and Firestore rules.',
                );
              }

              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final tasks = _orderedActiveTasks(snapshot.data!);

              if (tasks.isEmpty) {
                return _notice(
                  'Your training conversations will add next steps here.',
                );
              }

              return SizedBox(
                height: 260,
                child: ListView.separated(
                  primary: false,
                  itemCount: tasks.length,
                  separatorBuilder: (_, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final data = task.data();

                    return ListTile(
                      leading: Checkbox(
                        value: false,
                        onChanged: _busy
                            ? null
                            : (_) =>
                                  _run(() => _repository.completeTask(task.id)),
                      ),
                      title: Text(data['title'] as String),
                      subtitle: const Text('Tap for step-by-step guidance'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _busy ? null : () => _openTask(task.id),
                    );
                  },
                ),
              );
            },
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_error!),
          ),
        const SizedBox(height: 28),
        _heading('Previous Chats'),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _sessions,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _notice('Unable to load previous conversations.');
              }

              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final sessions = snapshot.data!.docs.where((document) {
                final data = document.data();
                final messageCount =
                    (data['messageCount'] as num?)?.toInt() ?? 0;
                final archived = data['archived'] == true;

                return messageCount > 0 && !archived;
              }).toList();

              if (sessions.isEmpty) {
                return _notice('Your saved conversations will appear here.');
              }

              return SizedBox(
                height: 240,
                child: ListView.separated(
                  primary: false,
                  itemCount: sessions.length,
                  separatorBuilder: (_, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final data = session.data();
                    final explanation = data['type'] == 'taskExplanation';

                    return ListTile(
                      leading: Icon(
                        explanation
                            ? Icons.menu_book_outlined
                            : Icons.chat_bubble_outline,
                      ),
                      title: Text(
                        data['title'] as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        explanation
                            ? 'Task explanation'
                            : 'Training conversation',
                      ),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Conversation options',
                        enabled: !_busy,
                        onSelected: (value) {
                          if (value == 'remove') {
                            _removeConversation(
                              session.id,
                              data['title'] as String,
                            );
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem<String>(
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(Icons.archive_outlined),
                                SizedBox(width: 10),
                                Text('Remove from history'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      onTap: _busy
                          ? null
                          : () => _run(() => _openChat(session.id)),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
