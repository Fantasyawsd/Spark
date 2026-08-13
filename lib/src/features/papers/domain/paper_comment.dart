class PaperComment {
  const PaperComment({
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

  PaperComment copyWith({int? likes, String? body}) {
    return PaperComment(
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
