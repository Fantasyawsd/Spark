import '../../../core/storage/local_json_store.dart';
import '../domain/paper_comment_repository.dart';

class FilePaperCommentRepository implements PaperCommentRepository {
  FilePaperCommentRepository({LocalJsonStore? store})
      : _store = store ?? LocalJsonStore(fileName: 'paper_comments.json');

  final LocalJsonStore _store;

  @override
  Future<PaperCommentSnapshot> load(String paperId) async {
    try {
      final json = await _store.read();
      if (json == null) {
        return const PaperCommentSnapshot(comments: [], hasStoredValue: false);
      }
      if (json is! Map<String, dynamic>) {
        throw const FormatException('Comment data must be an object.');
      }
      final rawComments = json[paperId];
      final comments = rawComments is List
          ? rawComments.whereType<Map>().map(_fromJson).toList(growable: false)
          : const <PaperCommentRecord>[];
      return PaperCommentSnapshot(comments: comments, hasStoredValue: true);
    } catch (error) {
      throw PaperCommentPersistenceException('无法读取评论。', error);
    }
  }

  @override
  Future<void> save(String paperId, List<PaperCommentRecord> comments) async {
    try {
      final current = await _store.read();
      final json = current is Map<String, dynamic>
          ? Map<String, dynamic>.from(current)
          : <String, dynamic>{};
      json[paperId] = comments.map(_toJson).toList(growable: false);
      await _store.write(json);
    } catch (error) {
      throw PaperCommentPersistenceException('无法保存评论。', error);
    }
  }

  static PaperCommentRecord _fromJson(Map raw) {
    return PaperCommentRecord(
      id: raw['id'] as String? ?? '',
      paperId: raw['paperId'] as String? ?? '',
      name: raw['name'] as String? ?? 'PaperFlow 用户',
      initials: raw['initials'] as String? ?? 'PF',
      time: raw['time'] as String? ?? '刚刚',
      location: raw['location'] as String? ?? '',
      body: raw['body'] as String? ?? '',
      likes: raw['likes'] is int ? raw['likes'] as int : 0,
      parentId: raw['parentId'] as String?,
      isLocalUser: raw['isLocalUser'] == true,
      likedByLocalUser: raw['likedByLocalUser'] == true,
    );
  }

  static Map<String, Object?> _toJson(PaperCommentRecord comment) => {
        'id': comment.id,
        'paperId': comment.paperId,
        'name': comment.name,
        'initials': comment.initials,
        'time': comment.time,
        'location': comment.location,
        'body': comment.body,
        'likes': comment.likes,
        'parentId': comment.parentId,
        'isLocalUser': comment.isLocalUser,
        'likedByLocalUser': comment.likedByLocalUser,
      };
}
