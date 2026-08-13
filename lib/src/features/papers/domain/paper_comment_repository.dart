import 'paper_comment.dart';

class PaperCommentSnapshot {
  const PaperCommentSnapshot({
    required this.comments,
    required this.hasStoredValue,
  });

  final List<PaperComment> comments;
  final bool hasStoredValue;
}

abstract interface class PaperCommentRepository {
  Future<PaperCommentSnapshot> load(String paperId);
  Future<void> save(String paperId, List<PaperComment> comments);
}

class PaperCommentPersistenceException implements Exception {
  const PaperCommentPersistenceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
