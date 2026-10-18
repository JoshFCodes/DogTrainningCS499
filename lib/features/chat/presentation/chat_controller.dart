import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/chat_repository.dart';
import '../data/chat_service.dart';
import '../models/chat_message.dart';

class ChatController extends ChangeNotifier {
  ChatController(this._service, this._repository, {String? sessionId})
    : _existingSession = sessionId != null,
      _sessionId = sessionId ?? _repository.newSessionId();

  final ChatService _service;
  final ChatRepository _repository;
  final bool _existingSession;
  final String _sessionId;

  SavedChat? _saved;
  bool _ready = false;
  bool _busy = false;
  bool _disposed = false;
  String? _error;

  String? _draft;
  int? _draftSequence;

  ChatReply? _unsavedReply;
  int? _replySequence;

  List<ChatMessage> get messages => _saved?.messages ?? const [];

  String get title => _saved?.title ?? 'Chat';

  bool get isSending => _busy;
  bool get isReady => _ready;
  String? get error => _error;

  bool get canSend =>
      _ready && !_busy && _error == null && !(_saved?.awaitingReply ?? false);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    if (_disposed || _busy) return;

    await _run(() async {
      if (!_existingSession) {
        await _repository.ensureTrainingSession(_sessionId);
      }

      _saved = await _repository.load(_sessionId);
      _ready = true;
      _notify();

      if (_disposed) return;

      if (_saved!.messages.isEmpty && _saved!.initialPrompt.isNotEmpty) {
        _draft = _saved!.initialPrompt;
        _draftSequence = 0;

        await _saveDraft();
        await _finishTurn();
      } else if (_saved!.awaitingReply) {
        _error =
            'The last message has no saved reply yet. '
            'Tap Retry to continue.';
      }
    });
  }

  Future<void> send(String input) async {
    if (!canSend || _disposed) return;

    final text = input.trim();
    if (text.isEmpty) return;

    if (text.length > 8000) {
      _error = 'Please keep each message under 8,000 characters.';
      _notify();
      return;
    }

    _draft = text;
    _draftSequence = messages.length;

    await _run(() async {
      await _saveDraft();
      await _finishTurn();
    });
  }

  Future<void> retry() async {
    if (_disposed || _busy) return;

    if (!_ready) {
      await initialize();
      return;
    }

    await _run(() async {
      await _saveDraft();

      _saved = await _repository.load(_sessionId);
      _notify();

      if (!_disposed) await _finishTurn();
    });
  }

  Future<void> _saveDraft() async {
    if (_draft == null) return;

    await _repository.appendUser(_sessionId, _draftSequence!, _draft!);

    _draft = null;
    _draftSequence = null;

    _saved = await _repository.load(_sessionId);
    _notify();
  }

  Future<void> _finishTurn() async {
    _saved = await _repository.load(_sessionId);
    _notify();

    if (!_saved!.awaitingReply) {
      _unsavedReply = null;
      _replySequence = null;
      return;
    }

    // If the page was closed before generation began, leave the
    // saved user message available for Retry when reopened.
    if (_disposed) return;

    final sequence = _saved!.messages.length;

    if (_unsavedReply == null || _replySequence != sequence) {
      _unsavedReply = await _service
          .generateReply(
            _saved!.messages,
            allowTasks: _saved!.allowsTasks,
            context: _saved!.context,
          )
          .timeout(const Duration(seconds: 120));

      _replySequence = sequence;
    }

    // An in-flight reply can still finish saving after this page closes,
    // provided the app remains running and the account has not changed.
    await _repository.saveReply(_sessionId, sequence, _unsavedReply!);

    _saved = await _repository.load(_sessionId);
    _unsavedReply = null;
    _replySequence = null;
    _notify();
  }

  Future<void> _run(Future<void> Function() operation) async {
    _busy = true;
    _error = null;
    _notify();

    try {
      await operation();
    } on TimeoutException {
      _error =
          'The response took too long. Your saved message is '
          'still available. Tap Retry.';
    } on ChatReplyException catch (error) {
      _error = error.message;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Chat operation failed: $error');
      }

      _error =
          'Unable to finish this operation. Check your connection '
          'and tap Retry.';
    } finally {
      _busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
