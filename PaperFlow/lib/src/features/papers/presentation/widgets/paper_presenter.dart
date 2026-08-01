import '../../domain/paper.dart';

String compactAuthorLine(Paper paper) {
  final names = paper.authors.where((name) => name.trim().isNotEmpty).toList();
  final author =
      names.length <= 1 ? paper.firstAuthor : '${paper.firstAuthor} 等';
  final affiliation = paper.firstAffiliation.trim();
  if (affiliation.isEmpty || affiliation.toLowerCase() == 'arxiv') {
    return author;
  }
  return '$author · $affiliation';
}

String adjustedCompactCount(int value, {int delta = 0}) {
  final count = (value + delta).clamp(0, 1 << 31);
  if (count < 1000) return '$count';
  if (count < 1000000) {
    final formatted = (count / 1000).toStringAsFixed(1);
    return '${formatted.endsWith('.0') ? formatted.substring(0, formatted.length - 2) : formatted}k';
  }
  final formatted = (count / 1000000).toStringAsFixed(1);
  return '${formatted.endsWith('.0') ? formatted.substring(0, formatted.length - 2) : formatted}m';
}
