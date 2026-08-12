import '../domain/paper.dart';
import '../domain/paper_feed_filter.dart';
import '../domain/paper_time_range.dart';

class PaperFeedProjector {
  const PaperFeedProjector._();

  static List<Paper> fallback({
    required Iterable<Paper> papers,
    required String channelKey,
    required PaperFeedMode mode,
    required Set<String> followedPaperIds,
    required PaperTimeRange timeRange,
  }) {
    final candidates = _candidatesForChannel(papers, channelKey);
    return PaperFeedFilter.apply(
      papers: candidates,
      mode: mode,
      followedPaperIds: followedPaperIds,
      timeRange: timeRange,
    );
  }

  static List<Paper> mergeCatalogPage({
    required Iterable<Paper> existing,
    required Iterable<Paper> incoming,
    required bool append,
  }) {
    final incomingPapers = incoming.toList(growable: false);
    if (!append && incomingPapers.isEmpty) return const [];
    final incomingById = <String, Paper>{
      for (final paper in incomingPapers) paper.id: paper,
    };
    final existingPapers = existing.toList(growable: false);
    final ordered = append
        ? [
            for (final paper in existingPapers) incomingById[paper.id] ?? paper,
            ...incomingPapers,
          ]
        : [...incomingPapers, ...existingPapers];
    final seen = <String>{};
    return List.unmodifiable([
      for (final paper in ordered)
        if (seen.add(paper.id)) paper,
    ]);
  }

  static Iterable<Paper> _candidatesForChannel(
    Iterable<Paper> papers,
    String channelKey,
  ) {
    if (channelKey.startsWith('fixed:')) return papers;
    const subjectPrefix = 'subject:';
    if (!channelKey.startsWith(subjectPrefix)) return const [];
    final code = channelKey.substring(subjectPrefix.length);
    return papers.where((paper) => paper.subjects.contains(code));
  }
}
