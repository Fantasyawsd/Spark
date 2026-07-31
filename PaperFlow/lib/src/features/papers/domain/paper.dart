enum PaperAccent { blue, purple, green, pink, azure, orange }

class PaperRecord {
  const PaperRecord({
    required this.id,
    required this.venue,
    required this.title,
    required this.authors,
    required this.firstAffiliation,
    required this.topics,
    required this.abstractText,
    required this.chineseAbstractMarkdown,
    required this.relatedPapersMarkdown,
    required this.readMinutes,
    required this.citations,
    required this.likes,
    required this.comments,
    required this.saves,
    required this.shares,
    required this.accent,
  });

  final String id;
  final String venue;
  final String title;
  final String authors;
  final String firstAffiliation;
  final List<String> topics;
  final String abstractText;
  final String chineseAbstractMarkdown;
  final String relatedPapersMarkdown;
  final int readMinutes;
  final String citations;
  final String likes;
  final String comments;
  final String saves;
  final String shares;
  final PaperAccent accent;
}
