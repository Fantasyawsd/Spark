import 'dart:async';

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

  /// 会话数据发生变更（save / clear / setPinned 成功）时发出事件，
  /// 供会话列表控制器订阅后自动刷新。
  Stream<void> get changes;
}

class ChatSessionPersistenceException implements Exception {
  const ChatSessionPersistenceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
