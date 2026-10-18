import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/chat_message.dart';
import 'chat_service.dart';

class SavedChat {
  const SavedChat({
    required this.id,
    required this.data,
    required this.messages,
  });

  final String id;
  final Map<String, dynamic> data;
  final List<ChatMessage> messages;

  String get title => data['title'] as String;
  String get context => data['context'] as String;
  String get initialPrompt => data['initialPrompt'] as String;

  bool get allowsTasks => data['type'] == 'training';

  bool get awaitingReply =>
      messages.isNotEmpty && messages.last.role == MessageRole.user;
}

class ChatRepository {
  ChatRepository(this.uid);

  final String uid;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _user =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _user.collection('sessions');

  CollectionReference<Map<String, dynamic>> get _tasks =>
      _user.collection('tasks');

  String newSessionId() => _sessions.doc().id;

  void _checkUser() {
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw const ChatReplyException('Your session changed. Sign in again.');
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSessions() {
    _checkUser();
    return _sessions.orderBy('updatedAt', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchTasks() {
    _checkUser();
    return _tasks.orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> archiveSession(String sessionId) async {
    _checkUser();

    await _sessions.doc(sessionId).update({
      'archived': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> _buildProfileContext() async {
    _checkUser();

    final userSnapshot = await _user.get(
      const GetOptions(source: Source.server),
    );

    // Two results are enough to distinguish:
    // zero pets, exactly one pet, or multiple pets.
    final petsSnapshot = await _user
        .collection('pets')
        .limit(2)
        .get(const GetOptions(source: Source.server));

    _checkUser();

    final userData = userSnapshot.data() ?? <String, dynamic>{};

    final context = <String, dynamic>{
      'contextVersion': 1,
      'capturedAt': DateTime.now().toUtc().toIso8601String(),
      'owner': {
        'displayName': userData['displayName'] as String? ?? '',
        'trainingExperience': userData['experience'] as String? ?? 'beginner',
      },
    };

    if (petsSnapshot.docs.isEmpty) {
      context['petSelectionStatus'] = 'no_saved_pets';
    } else if (petsSnapshot.docs.length == 1) {
      final pet = petsSnapshot.docs.single.data();

      context['petSelectionStatus'] = 'single_pet_selected';

      // Explicitly select the fields useful for training.
      context['pet'] = {
        'name': pet['name'] as String? ?? '',
        'breed': pet['breed'] as String? ?? '',
        'birthDate': pet['birthDate'] as String? ?? '',
        'currentFocus': pet['focus'] as String? ?? '',
        'trainingGoals': pet['goals'] as String? ?? '',
        'notes': pet['notes'] as String? ?? '',
      };
    } else {
      context['petSelectionStatus'] = 'multiple_pets_no_selection';

      // Do not attach one pet's details until a selection is made.
    }

    final encoded = jsonEncode(context);

    if (encoded.length > 60000) {
      throw const ChatReplyException(
        'The profile information is too large to start this session.',
      );
    }

    return encoded;
  }

  Future<void> ensureTrainingSession(String id) async {
    _checkUser();

    final ref = _sessions.doc(id);

    // A retry must not replace an existing conversation's context.
    final existing = await ref.get(const GetOptions(source: Source.server));

    if (existing.exists) return;

    final profileContext = await _buildProfileContext();

    _checkUser();

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);

      // Another attempt may have created the session meanwhile.
      if (snapshot.exists) return;

      transaction.set(ref, {
        'title': 'New training session',
        'type': 'training',
        'context': profileContext,
        'initialPrompt': '',
        'sourceTaskId': '',
        'messageCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<SavedChat> load(String id) async {
    _checkUser();

    final ref = _sessions.doc(id);
    final snapshot = await ref.get(const GetOptions(source: Source.server));

    if (!snapshot.exists) {
      throw const ChatReplyException('This conversation was not found.');
    }

    final data = snapshot.data()!;
    final count = data['messageCount'] as int;

    final messages = <ChatMessage>[];

    if (count > 0) {
      // Load the prefix described by the session snapshot. If another
      // device appends a message meanwhile, the prefix remains valid.
      final result = await ref
          .collection('messages')
          .where('sequence', isLessThan: count)
          .orderBy('sequence')
          .get(const GetOptions(source: Source.server));

      if (result.docs.length != count) {
        throw const ChatReplyException(
          'The conversation could not be fully loaded. Please retry.',
        );
      }

      for (var index = 0; index < result.docs.length; index++) {
        final message = result.docs[index].data();

        if (message['sequence'] != index) {
          throw const ChatReplyException('Message ordering is invalid.');
        }

        messages.add(
          ChatMessage(
            role: message['role'] == 'user'
                ? MessageRole.user
                : MessageRole.assistant,
            text: message['text'] as String,
          ),
        );
      }
    }

    _checkUser();

    return SavedChat(id: id, data: data, messages: List.unmodifiable(messages));
  }

  Future<void> appendUser(String sessionId, int sequence, String text) async {
    _checkUser();

    if (text.isEmpty || text.length > 8000 || sequence.isOdd) {
      throw const ChatReplyException(
        'Send a message of 1–8,000 characters after the previous reply.',
      );
    }

    final session = _sessions.doc(sessionId);
    final message = session.collection('messages').doc('$sequence');

    await _db.runTransaction((transaction) async {
      final sessionSnapshot = await transaction.get(session);
      final existingMessage = await transaction.get(message);

      // A previous attempt may have saved successfully even if
      // the client did not receive its acknowledgement.
      if (existingMessage.exists) {
        final existing = existingMessage.data()!;

        if (existing['role'] == 'user' && existing['text'] == text) {
          return;
        }

        throw const ChatReplyException(
          'This conversation changed elsewhere. Reopen it to continue.',
        );
      }

      final data = sessionSnapshot.data();

      if (data == null || data['messageCount'] != sequence) {
        throw const ChatReplyException(
          'This conversation changed elsewhere. Reopen it to continue.',
        );
      }

      transaction.set(message, {
        'sequence': sequence,
        'role': 'user',
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.update(session, {
        'messageCount': sequence + 1,
        'updatedAt': FieldValue.serverTimestamp(),
        if (sequence == 0 && data['type'] == 'training')
          'title': text.length > 80 ? text.substring(0, 80) : text,
      });
    });
  }

  Future<void> saveReply(
    String sessionId,
    int sequence,
    ChatReply reply,
  ) async {
    _checkUser();

    if (sequence.isEven || reply.text.isEmpty || reply.text.length > 20000) {
      throw const ChatReplyException('The response could not be saved.');
    }

    final session = _sessions.doc(sessionId);
    final message = session.collection('messages').doc('$sequence');

    await _db.runTransaction((transaction) async {
      final sessionSnapshot = await transaction.get(session);
      final existingMessage = await transaction.get(message);

      // If another attempt already finished this turn, keep its answer.
      if (existingMessage.exists) return;

      final data = sessionSnapshot.data();

      if (data == null || data['messageCount'] != sequence) {
        throw const ChatReplyException(
          'This conversation changed elsewhere. Reopen it to continue.',
        );
      }

      transaction.set(message, {
        'sequence': sequence,
        'role': 'assistant',
        'text': reply.text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (data['type'] == 'training') {
        for (var index = 0; index < reply.tasks.length; index++) {
          final task = reply.tasks[index];

          transaction.set(_tasks.doc('${sessionId}_${sequence}_$index'), {
            'title': task.title,
            'details': task.details,
            'stepOrder': index,
            'sourceSessionId': sessionId,
            'sourceMessageId': '$sequence',
            'completed': false,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      transaction.update(session, {
        'messageCount': sequence + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> completeTask(String taskId) async {
    _checkUser();

    await _tasks.doc(taskId).update({
      'completed': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> explanationFor(String taskId) async {
    _checkUser();

    // Each task gets one dedicated explanation conversation.
    final id = 'task_$taskId';
    final session = _sessions.doc(id);

    final existing = await session.get(const GetOptions(source: Source.server));

    if (existing.exists) return id;

    final taskSnapshot = await _tasks
        .doc(taskId)
        .get(const GetOptions(source: Source.server));

    if (!taskSnapshot.exists) {
      throw const ChatReplyException('This task no longer exists.');
    }

    final task = taskSnapshot.data()!;
    final original = await load(task['sourceSessionId'] as String);
    final sourceSequence = int.parse(task['sourceMessageId'] as String);

    final sourceMessages = original.messages.take(sourceSequence + 1).toList();

    // Include the first message and up to twelve recent messages.
    // Bound individual excerpts so the context document stays small.
    final indexes = <int>{};

    if (sourceMessages.isNotEmpty) indexes.add(0);

    final start = sourceMessages.length > 12 ? sourceMessages.length - 12 : 0;

    for (var index = start; index < sourceMessages.length; index++) {
      indexes.add(index);
    }

    final context = jsonEncode({
      // Preserve the profile snapshot from the original training session.
      'sourceSessionContext': original.context,

      'conversationExcerpts': indexes.map((index) {
        final message = sourceMessages[index];
        final text = message.text;

        return {
          'role': message.role.name,
          'text': text.length > 3500
              ? '${text.substring(0, 3500)} [excerpt truncated]'
              : text,
        };
      }).toList(),
    });

    if (context.length > 60000) {
      throw const ChatReplyException(
        'The source context is too large to open this explanation.',
      );
    }

    final title = task['title'] as String;
    final prompt =
        'Explain this training task in more depth:\n\n'
        '$title\n\n${task['details']}\n\n'
        'Give practical instructions, timing, and signs of progress. '
        'Focus on this task rather than proposing additional activities.';

    _checkUser();

    await _db.runTransaction((transaction) async {
      final current = await transaction.get(session);
      if (current.exists) return;

      transaction.set(session, {
        'title': title,
        'type': 'taskExplanation',
        'context': context,
        'initialPrompt': prompt,
        'sourceTaskId': taskId,
        'messageCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    return id;
  }
}
