import '../domain/paper_comment.dart';

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

  factory PaperCommentRecord.fromDomain(PaperComment comment) {
    return PaperCommentRecord(
      id: comment.id,
      paperId: comment.paperId,
      name: comment.name,
      initials: comment.initials,
      time: comment.time,
      location: comment.location,
      body: comment.body,
      likes: comment.likes,
      parentId: comment.parentId,
      isLocalUser: comment.isLocalUser,
      likedByLocalUser: comment.likedByLocalUser,
    );
  }

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

  PaperComment toDomain() {
    return PaperComment(
      id: id,
      paperId: paperId,
      name: name,
      initials: initials,
      time: time,
      location: location,
      body: body,
      likes: likes,
      parentId: parentId,
      isLocalUser: isLocalUser,
      likedByLocalUser: likedByLocalUser,
    );
  }
}
