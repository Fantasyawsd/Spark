import '../../domain/paper.dart';

String compactAuthorLine(Paper paper) {
  final names = paper.authors.where((name) => name.trim().isNotEmpty).toList();
  final author =
      names.length <= 1 ? paper.firstAuthor : '${paper.firstAuthor} 等';
  final affiliation = paper.firstAffiliation;
  if (affiliation == null) {
    return author;
  }
  return '$author · $affiliation';
}

/// 展示用来源标签：真实 venue / 期刊引用未知时回退到来源名称（如 arXiv）。
String venueLabel(Paper paper) {
  final venue = paper.venue ?? paper.journalReference;
  if (venue != null && venue.trim().isNotEmpty) return venue;
  return paper.source == 'arxiv' ? 'arXiv' : paper.source;
}

/// 主题 chip 文案：优先内容关键词，其次 arXiv 分类；均为空时返回 null。
String? topicLabel(Paper paper) {
  for (final keyword in paper.contentKeywords) {
    if (keyword.trim().isNotEmpty) return keyword;
  }
  final primarySubject = paper.primarySubject;
  if (primarySubject != null && primarySubject.trim().isNotEmpty) {
    return primarySubject;
  }
  for (final subject in paper.subjects) {
    if (subject.trim().isNotEmpty) return subject;
  }
  return null;
}

/// 展示用热点 chip 文案：返回 `Trending · 原因`；原因超长截断加省略号。
/// 无热点原因时返回 null，不渲染。
String? trendLabel(Paper paper) {
  final reason = paper.webTrendReason;
  if (reason == null || reason.trim().isEmpty) return null;
  final clamped = reason.trim().length > 24
      ? '${reason.trim().substring(0, 24)}…'
      : reason.trim();
  return 'Trending · $clamped';
}

/// 个性化推荐 chip 文案：个性化分数为正时返回「为你推荐」；
/// 分数缺失或非正时返回 null，不渲染。
String? personalizationLabel(Paper paper) {
  final score = paper.personalizationScore;
  if (score == null || score <= 0) return null;
  return '为你推荐';
}

/// 引用数文案；引用数未知时返回 null，不显示「被引 0」。
String? citationLine(Paper paper) {
  final citations = paper.metrics.citations;
  if (citations == null) return null;
  return '被引 ${adjustedCompactCount(citations)}';
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
