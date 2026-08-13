import '../../../core/storage/local_json_store.dart';
import '../../../core/storage/versioned_local_json_store.dart';
import '../domain/paper_comment.dart';
import '../domain/paper_comment_repository.dart';
import 'paper_comment_json_mapper.dart';
import 'paper_comment_record.dart';

class FilePaperCommentRepository implements PaperCommentRepository {
  FilePaperCommentRepository({LocalJsonStore? store})
      : _store = VersionedLocalJsonStore(
          store ?? LocalJsonStore(fileName: 'paper_comments.json'),
          schemaId: 'papers.comments',
          validatePayload: PaperCommentJsonMapper.validatePayload,
        );

  final VersionedLocalJsonStore _store;

  @override
  Future<PaperCommentSnapshot> load(String paperId) async {
    try {
      final json = await _store.readMap();
      if (json == null) {
        return const PaperCommentSnapshot(comments: [], hasStoredValue: false);
      }
      final comments = PaperCommentJsonMapper.commentsFor(
        json,
        paperId,
      ).map((record) => record.toDomain()).toList(growable: false);
      return PaperCommentSnapshot(comments: comments, hasStoredValue: true);
    } catch (error) {
      throw PaperCommentPersistenceException('无法读取评论。', error);
    }
  }

  @override
  Future<void> save(String paperId, List<PaperComment> comments) async {
    try {
      await _store.updateMap((current) {
        final json = current ?? <String, dynamic>{};
        json[paperId] = comments
            .map(PaperCommentRecord.fromDomain)
            .map(PaperCommentJsonMapper.toJson)
            .toList(growable: false);
        return json;
      });
    } catch (error) {
      throw PaperCommentPersistenceException('无法保存评论。', error);
    }
  }
}
