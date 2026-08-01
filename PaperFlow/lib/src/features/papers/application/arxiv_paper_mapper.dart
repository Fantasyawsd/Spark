import '../domain/paper.dart';
import '../domain/paper_source.dart';

extension ArxivPaperMapping on ArxivMetadata {
  Paper toPaper({
    int? citationCount,
    List<RelatedPaper> relatedPapers = const [],
  }) {
    final topicLabels = <String>{
      ...categories,
      if (primaryCategory != null) primaryCategory!,
    }.toList(growable: false);
    return Paper(
      id: normalizedId,
      venue: journalReference ?? 'arXiv',
      title: title,
      authors: List.unmodifiable(authors),
      firstAffiliation: 'arXiv',
      topics: topicLabels.isEmpty ? const ['arXiv'] : topicLabels,
      abstractText: abstractText,
      chineseAbstractMarkdown: '中文摘要尚未生成。',
      relatedPapers: relatedPapers,
      readMinutes: _estimateReadMinutes(abstractText),
      citations: citationCount ?? 0,
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

extension PaperEnhancementMapping on Paper {
  Paper copyWithEnhancement(PaperEnhancement enhancement) {
    return Paper(
      id: id,
      venue: venue,
      title: title,
      authors: authors,
      firstAffiliation: enhancement.institutions.isEmpty
          ? firstAffiliation
          : enhancement.institutions.first,
      topics: {...topics, ...enhancement.concepts}.toList(growable: false),
      abstractText: content.originalAbstractMarkdown,
      chineseAbstractMarkdown: content.chineseAbstractMarkdown,
      relatedPapers: relatedPapers,
      readMinutes: readMinutes,
      citations: enhancement.citationCount ?? metrics.citations,
      likes: metrics.likes,
      comments: metrics.comments,
      saves: metrics.saves,
      shares: metrics.shares,
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
