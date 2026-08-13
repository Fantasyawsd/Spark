import '../domain/paper_comment.dart';
import '../domain/paper_comment_repository.dart';

class InMemoryPaperCommentRepository implements PaperCommentRepository {
  final Map<String, List<PaperComment>> _comments = {};

  @override
  Future<PaperCommentSnapshot> load(String paperId) async {
    final comments = _comments[paperId];
    return PaperCommentSnapshot(
      comments: List.unmodifiable(comments ?? const []),
      hasStoredValue: comments != null,
    );
  }

  @override
  Future<void> save(String paperId, List<PaperComment> comments) async {
    _comments[paperId] = List.of(comments);
  }
}
