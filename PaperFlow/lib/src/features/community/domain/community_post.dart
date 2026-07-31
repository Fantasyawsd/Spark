class CommunityPost {
  const CommunityPost({
    required this.author,
    required this.affiliation,
    required this.time,
    required this.avatarUrl,
    required this.content,
    required this.tags,
    required this.likes,
    required this.comments,
    required this.saves,
    required this.shares,
    this.paperTitle,
    this.venue,
    this.attachment,
    this.verified = false,
  });

  final String author;
  final String affiliation;
  final String time;
  final String avatarUrl;
  final String content;
  final List<String> tags;
  final String likes;
  final String comments;
  final String saves;
  final String shares;
  final String? paperTitle;
  final String? venue;
  final String? attachment;
  final bool verified;
}
