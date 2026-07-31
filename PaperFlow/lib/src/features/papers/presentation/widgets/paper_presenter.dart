import '../../domain/paper.dart';

String compactAuthorLine(PaperRecord paper) {
  final names = paper.authors
      .split(',')
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .toList();
  final author = names.length <= 1 ? paper.authors : '${names.first} 等';
  final affiliation = paper.firstAffiliation.trim();
  if (affiliation.isEmpty || affiliation.toLowerCase() == 'arxiv') {
    return author;
  }
  return '$author · $affiliation';
}

String? compactCountOrNull(String value, {int delta = 0}) {
  final normalized = adjustedCompactCount(value, delta: delta).trim();
  if (normalized.isEmpty || _isZeroCount(normalized)) return null;
  return normalized;
}

bool _isZeroCount(String value) {
  final normalized = value.replaceAll(',', '').trim().toLowerCase();
  final multiplier = normalized.endsWith('k')
      ? 1000
      : normalized.endsWith('m')
          ? 1000000
          : 1;
  final numeric = double.tryParse(
    multiplier == 1
        ? normalized
        : normalized.substring(0, normalized.length - 1),
  );
  return numeric != null && numeric * multiplier <= 0;
}

String adjustedCompactCount(String value, {int delta = 0}) {
  if (delta == 0) return value;
  final normalized = value.replaceAll(',', '').trim().toLowerCase();
  final multiplier = normalized.endsWith('k')
      ? 1000
      : normalized.endsWith('m')
          ? 1000000
          : 1;
  final number = double.tryParse(
    multiplier == 1
        ? normalized
        : normalized.substring(0, normalized.length - 1),
  );
  if (number == null) return value;
  final count = ((number * multiplier).round() + delta).clamp(0, 1 << 31);
  if (count < 1000) return '$count';
  if (count < 1000000) {
    final formatted = (count / 1000).toStringAsFixed(1);
    return '${formatted.endsWith('.0') ? formatted.substring(0, formatted.length - 2) : formatted}k';
  }
  final formatted = (count / 1000000).toStringAsFixed(1);
  return '${formatted.endsWith('.0') ? formatted.substring(0, formatted.length - 2) : formatted}m';
}
