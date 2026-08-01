import 'chat_message.dart';

class ChatSessionSummary {
  const ChatSessionSummary({
    required this.contextId,
    required this.messageCount,
    required this.preview,
    required this.updatedAt,
    this.pinned = false,
  });

  final String contextId;

  @Deprecated('Use contextId. This alias remains during the chat migration.')
  String get paperId => contextId;

  final int messageCount;
  final String preview;
  final DateTime updatedAt;
  final bool pinned;
}

abstract interface class ChatSessionRepository {
  Future<List<ChatMessage>> load(String contextId);

  Future<void> save(String contextId, List<ChatMessage> messages);

  Future<void> clear(String contextId);

  Future<void> setPinned(String contextId, bool pinned);

  Future<List<ChatSessionSummary>> listSessions();
}

class ChatSessionPersistenceException implements Exception {
  const ChatSessionPersistenceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
