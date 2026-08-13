import 'dart:async';

import '../../../core/diagnostics/diagnostics.dart';

/// Serializes conversation persistence writes without owning conversation state.
class ChatConversationWriteQueue {
  ChatConversationWriteQueue({required this.onQueueError});

  final void Function(Object error, StackTrace stackTrace) onQueueError;
  Future<void> _pending = Future.value();

  Future<void> enqueue(Future<void> Function() operation) {
    final queued = _pending.then((_) => operation());
    _pending = queued.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        onQueueError(error, stackTrace);
      },
    );
    return queued;
  }

  Future<void> flush() => _pending;
}

void reportChatConversationWriteQueueError(
  Object error,
  StackTrace stackTrace,
) {
  SparkDiagnostics.reportUnexpected(
    operation: SparkDiagnosticOperation.chatConversationWriteQueue,
    error: error,
    stackTrace: stackTrace,
  );
}
