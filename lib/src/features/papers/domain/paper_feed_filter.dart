import 'paper.dart';

enum PaperFeedMode { recommended, following, latest }

class PaperFeedFilter {
  const PaperFeedFilter._();

  static List<Paper> apply({
    required Iterable<Paper> papers,
    required PaperFeedMode mode,
    required Set<String> followedPaperIds,
  }) {
    final result = switch (mode) {
      PaperFeedMode.recommended => papers.toList(),
      PaperFeedMode.following => papers
          .where((paper) =>
              followedPaperIds.contains(paper.authorKey) ||
              followedPaperIds.contains(paper.id))
          .toList(),
      PaperFeedMode.latest => papers.toList()
        ..sort((left, right) {
          final byDate = _publishedAt(right).compareTo(_publishedAt(left));
          return byDate != 0 ? byDate : left.id.compareTo(right.id);
        }),
    };
    return List.unmodifiable(result);
  }

  static DateTime _publishedAt(Paper paper) =>
      paper.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
}
