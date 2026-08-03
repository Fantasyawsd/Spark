import 'paper.dart';

enum PaperFeedMode { recommended, following, latest }

class PaperFeedFilter {
  const PaperFeedFilter._();

  static List<Paper> apply({
    required Iterable<Paper> papers,
    required PaperFeedMode mode,
    String? subjectCode,
    required Set<String> followedPaperIds,
  }) {
    final result = switch (mode) {
      PaperFeedMode.recommended =>
        papers.where((paper) => _matchesSubject(paper, subjectCode)).toList(),
      PaperFeedMode.following => papers
          .where((paper) =>
              followedPaperIds.contains(paper.authorKey) ||
              followedPaperIds.contains(paper.id))
          .toList(),
      PaperFeedMode.latest =>
        papers.where((paper) => _matchesSubject(paper, subjectCode)).toList()
          ..sort((left, right) {
            final byDate = _publishedAt(right).compareTo(_publishedAt(left));
            return byDate != 0 ? byDate : left.id.compareTo(right.id);
          }),
    };
    return List.unmodifiable(result);
  }

  static bool _matchesSubject(Paper paper, String? subjectCode) {
    if (subjectCode == null) return true;
    return paper.subjects.contains(subjectCode);
  }

  static DateTime _publishedAt(Paper paper) =>
      paper.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
}
