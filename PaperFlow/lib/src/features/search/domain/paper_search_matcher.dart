import '../../papers/domain/paper.dart';

class PaperSearchMatcher {
  const PaperSearchMatcher._();

  static List<PaperRecord> search(
    Iterable<PaperRecord> papers,
    String query,
  ) {
    final terms = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList(growable: false);
    if (terms.isEmpty) return const [];

    final matches = papers.where((paper) {
      final searchable = [
        paper.title,
        paper.authors,
        paper.venue,
        paper.firstAffiliation,
        ...paper.topics,
      ].join(' ').toLowerCase();
      return terms.every(searchable.contains);
    }).toList();

    matches.sort((left, right) {
      final normalizedQuery = query.trim().toLowerCase();
      final leftStarts = left.title.toLowerCase().startsWith(normalizedQuery);
      final rightStarts = right.title.toLowerCase().startsWith(normalizedQuery);
      if (leftStarts != rightStarts) return leftStarts ? -1 : 1;
      return left.title.compareTo(right.title);
    });
    return List.unmodifiable(matches);
  }
}
