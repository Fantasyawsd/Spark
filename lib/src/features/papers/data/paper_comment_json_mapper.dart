import 'paper_comment_record.dart';
import 'paper_json_value_reader.dart';

class PaperCommentJsonMapper {
  const PaperCommentJsonMapper._();

  static void validatePayload(Object? payload) {
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Paper comment payload must be an object.');
    }
    for (final entry in payload.entries) {
      final comments = entry.value;
      if (comments is! List) {
        throw FormatException('Comments for ${entry.key} must be a list.');
      }
      for (final comment in comments) {
        fromJson(PaperJsonValueReader.stringMapValue(comment, 'comment'));
      }
    }
  }

  static List<PaperCommentRecord> commentsFor(
    Map<String, dynamic> json,
    String paperId,
  ) {
    final rawComments = json[paperId];
    if (rawComments == null) return const [];
    if (rawComments is! List) {
      throw FormatException('Comments for $paperId must be a list.');
    }
    return rawComments
        .map(
          (raw) =>
              fromJson(PaperJsonValueReader.stringMapValue(raw, 'comment')),
        )
        .toList(growable: false);
  }

  static PaperCommentRecord fromJson(Map<String, dynamic> raw) {
    return PaperCommentRecord(
      id: PaperJsonValueReader.requiredString(raw, 'id'),
      paperId: PaperJsonValueReader.requiredString(raw, 'paperId'),
      name: PaperJsonValueReader.requiredString(raw, 'name'),
      initials: PaperJsonValueReader.requiredString(raw, 'initials'),
      time: PaperJsonValueReader.requiredString(raw, 'time'),
      location: PaperJsonValueReader.optionalString(raw, 'location'),
      body: PaperJsonValueReader.requiredString(raw, 'body'),
      likes: PaperJsonValueReader.optionalInt(raw, 'likes'),
      parentId: PaperJsonValueReader.nullableString(raw, 'parentId'),
      isLocalUser: PaperJsonValueReader.optionalBool(raw, 'isLocalUser'),
      likedByLocalUser: PaperJsonValueReader.optionalBool(
        raw,
        'likedByLocalUser',
      ),
    );
  }

  static Map<String, Object?> toJson(PaperCommentRecord comment) => {
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
