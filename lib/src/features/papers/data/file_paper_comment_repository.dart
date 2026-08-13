import '../../../core/storage/local_json_store.dart';
import '../domain/paper_comment.dart';
import '../domain/paper_comment_repository.dart';
import 'paper_comment_json_mapper.dart';
import 'paper_comment_record.dart';
import 'paper_file_persistence.dart';

class FilePaperCommentRepository implements PaperCommentRepository {
  FilePaperCommentRepository({LocalJsonStore? store})
      : _persistence = PaperFilePersistence(
          fileName: 'paper_comments.json',
          schemaId: 'papers.comments',
          validatePayload: PaperCommentJsonMapper.validatePayload,
          store: store,
        );

  final PaperFilePersistence _persistence;

  @override
  Future<PaperCommentSnapshot> load(String paperId) {
    return _persistence.guard(() async {
      final json = await _persistence.store.readMap();
      if (json == null) {
        return const PaperCommentSnapshot(comments: [], hasStoredValue: false);
      }
      final comments = PaperCommentJsonMapper.commentsFor(
        json,
        paperId,
      ).map((record) => record.toDomain()).toList(growable: false);
      return PaperCommentSnapshot(comments: comments, hasStoredValue: true);
    }, (error) => PaperCommentPersistenceException('无法读取评论。', error));
  }

  @override
  Future<void> save(String paperId, List<PaperComment> comments) {
    return _persistence.guard(
      () => _persistence.store.updateMap((current) {
        final json = current ?? <String, dynamic>{};
        json[paperId] = comments
            .map(PaperCommentRecord.fromDomain)
            .map(PaperCommentJsonMapper.toJson)
            .toList(growable: false);
        return json;
      }),
      (error) => PaperCommentPersistenceException('无法保存评论。', error),
    );
  }
}
