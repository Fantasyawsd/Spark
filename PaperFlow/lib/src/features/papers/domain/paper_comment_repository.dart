class PaperCommentRecord {
  const PaperCommentRecord({
    required this.id,
    required this.paperId,
    required this.name,
    required this.initials,
    required this.time,
    required this.location,
    required this.body,
    required this.likes,
    this.parentId,
    this.isLocalUser = false,
    this.likedByLocalUser = false,
  });

  final String id;
  final String paperId;
  final String name;
  final String initials;
  final String time;
  final String location;
  final String body;
  final int likes;
  final String? parentId;
  final bool isLocalUser;
  final bool likedByLocalUser;

  PaperCommentRecord copyWith({int? likes, String? body}) {
    return PaperCommentRecord(
      id: id,
      paperId: paperId,
      name: name,
      initials: initials,
      time: time,
      location: location,
      body: body ?? this.body,
      likes: likes ?? this.likes,
      parentId: parentId,
      isLocalUser: isLocalUser,
      likedByLocalUser: likedByLocalUser,
    );
  }
}

class PaperCommentSnapshot {
  const PaperCommentSnapshot({
    required this.comments,
    required this.hasStoredValue,
  });

  final List<PaperCommentRecord> comments;
  final bool hasStoredValue;
}

abstract interface class PaperCommentRepository {
  Future<PaperCommentSnapshot> load(String paperId);
  Future<void> save(String paperId, List<PaperCommentRecord> comments);
}

class PaperCommentPersistenceException implements Exception {
  const PaperCommentPersistenceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
