import '../../papers/domain/paper.dart';

class PaperSearchMatcher {
  const PaperSearchMatcher._();

  static List<Paper> search(
    Iterable<Paper> papers,
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
        paper.authors.join(' '),
        paper.venue ?? '',
        paper.journalReference ?? '',
        paper.firstAffiliation ?? '',
        ...paper.contentKeywords,
        ...paper.subjects,
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
