import 'paper.dart';
import 'paper_time_range.dart';

enum PaperFeedMode { recommended, following, latest }

class PaperFeedFilter {
  const PaperFeedFilter._();

  static List<Paper> apply({
    required Iterable<Paper> papers,
    required PaperFeedMode mode,
    required Set<String> followedPaperIds,
    PaperTimeRange timeRange = const PaperTimeRange.all(),
    DateTime Function()? clock,
  }) {
    final now = (clock ?? DateTime.now)();
    final inRange = papers.where(
      (paper) => timeRange.includes(paper, now: now),
    );
    final result = switch (mode) {
      PaperFeedMode.recommended => inRange.toList(),
      PaperFeedMode.following => inRange
          .where((paper) =>
              followedPaperIds.contains(paper.authorKey) ||
              followedPaperIds.contains(paper.id))
          .toList(),
      PaperFeedMode.latest => inRange.toList()
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
