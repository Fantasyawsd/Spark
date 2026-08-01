String normalizeArxivId(String value) {
  var normalized = value.trim();
  normalized =
      normalized.replaceFirst(RegExp(r'^arXiv:', caseSensitive: false), '');
  normalized = normalized.replaceFirst(
    RegExp(r'^https?://(?:export\.)?arxiv\.org/(?:abs|pdf)/',
        caseSensitive: false),
    '',
  );
  normalized =
      normalized.replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '');
  return normalized.replaceFirst(RegExp(r'v\d+$', caseSensitive: false), '');
}
