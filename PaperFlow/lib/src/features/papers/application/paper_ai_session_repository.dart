import 'paper_ai_service.dart';

class PaperAiSessionSummary {
  const PaperAiSessionSummary({
    required this.paperId,
    required this.messageCount,
    required this.preview,
    required this.updatedAt,
    this.pinned = false,
  });

  final String paperId;
  final int messageCount;
  final String preview;
  final DateTime updatedAt;
  final bool pinned;
}

abstract interface class PaperAiSessionRepository {
  Future<List<PaperAiMessage>> load(String paperId);

  Future<void> save(String paperId, List<PaperAiMessage> messages);

  Future<void> clear(String paperId);

  Future<void> setPinned(String paperId, bool pinned);

  Future<List<PaperAiSessionSummary>> listSessions();
}

class PaperAiSessionPersistenceException implements Exception {
  const PaperAiSessionPersistenceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
