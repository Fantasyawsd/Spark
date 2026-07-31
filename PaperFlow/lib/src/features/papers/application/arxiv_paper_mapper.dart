import '../domain/paper.dart';
import '../domain/paper_source.dart';

extension ArxivPaperMapping on ArxivMetadata {
  PaperRecord toPaperRecord({int? citationCount}) {
    final topicLabels = <String>{
      ...categories,
      if (primaryCategory != null) primaryCategory!,
    }.toList(growable: false);
    return PaperRecord(
      id: normalizedId,
      venue: journalReference ?? 'arXiv',
      title: title,
      authors: authors.join(', '),
      firstAffiliation: 'arXiv',
      topics: topicLabels.isEmpty ? const ['arXiv'] : topicLabels,
      abstractText: abstractText,
      chineseAbstractMarkdown: '中文摘要尚未生成。',
      relatedPapersMarkdown: '相关论文将在数据增强后提供。',
      readMinutes: _estimateReadMinutes(abstractText),
      citations: _formatCount(citationCount ?? 0),
      likes: '0',
      comments: '0',
      saves: '0',
      shares: '0',
      arxivId: normalizedId,
      doi: doi,
      paperUrl: absUrl,
      pdfUrl: pdfUrl,
      publishedAt: publishedAt,
      updatedAt: updatedAt,
      license: license,
      source: 'arxiv',
    );
  }
}

extension PaperEnhancementMapping on PaperRecord {
  PaperRecord copyWithEnhancement(PaperEnhancement enhancement) {
    return PaperRecord(
      id: id,
      venue: venue,
      title: title,
      authors: authors,
      firstAffiliation: enhancement.institutions.isEmpty
          ? firstAffiliation
          : enhancement.institutions.first,
      topics: {...topics, ...enhancement.concepts}.toList(growable: false),
      abstractText: abstractText,
      chineseAbstractMarkdown: chineseAbstractMarkdown,
      relatedPapersMarkdown: relatedPapersMarkdown,
      readMinutes: readMinutes,
      citations: enhancement.citationCount == null
          ? citations
          : '${enhancement.citationCount}',
      likes: likes,
      comments: comments,
      saves: saves,
      shares: shares,
      arxivId: arxivId,
      doi: doi,
      paperUrl: paperUrl,
      pdfUrl: pdfUrl,
      publishedAt: publishedAt,
      updatedAt: updatedAt,
      license: license,
      source: source,
    );
  }
}

int _estimateReadMinutes(String text) {
  final words =
      text.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
  return (words / 180).ceil().clamp(1, 60);
}

String _formatCount(int count) {
  if (count < 1000) return '$count';
  if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}k';
  return '${(count / 1000000).toStringAsFixed(1)}m';
}
