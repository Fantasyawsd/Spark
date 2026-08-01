import '../domain/paper_comment_repository.dart';

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
        fromJson(_stringMap(comment, 'comment'));
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
        .map((raw) => fromJson(_stringMap(raw, 'comment')))
        .toList(growable: false);
  }

  static PaperCommentRecord fromJson(Map<String, dynamic> raw) {
    return PaperCommentRecord(
      id: _requiredString(raw, 'id'),
      paperId: _requiredString(raw, 'paperId'),
      name: _requiredString(raw, 'name'),
      initials: _requiredString(raw, 'initials'),
      time: _requiredString(raw, 'time'),
      location: _optionalString(raw, 'location'),
      body: _requiredString(raw, 'body'),
      likes: _optionalInt(raw, 'likes'),
      parentId: _nullableString(raw, 'parentId'),
      isLocalUser: _optionalBool(raw, 'isLocalUser'),
      likedByLocalUser: _optionalBool(raw, 'likedByLocalUser'),
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

  static Map<String, dynamic> _stringMap(Object? value, String label) {
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw FormatException('$label must be an object.');
    }
    return Map<String, dynamic>.from(value);
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String) throw FormatException('$key must be a string.');
    return value;
  }

  static String _optionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return '';
    if (value is! String) throw FormatException('$key must be a string.');
    return value;
  }

  static String? _nullableString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String) throw FormatException('$key must be a string.');
    return value;
  }

  static int _optionalInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return 0;
    if (value is! int) throw FormatException('$key must be an integer.');
    return value;
  }

  static bool _optionalBool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return false;
    if (value is! bool) throw FormatException('$key must be a boolean.');
    return value;
  }
}
