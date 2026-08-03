import '../domain/paper.dart';
import '../domain/paper_source.dart';

extension ArxivPaperMapping on ArxivMetadata {
  Paper toPaper({
    int? citationCount,
    List<RelatedPaper> relatedPapers = const [],
  }) {
    final subjects = <String>{
      ...categories,
      if (primaryCategory != null) primaryCategory!,
    }.toList(growable: false);
    return Paper(
      id: normalizedId,
      title: title,
      authors: List.unmodifiable(authors),
      subjects: subjects,
      primarySubject: primaryCategory,
      journalReference: journalReference,
      comment: comment,
      abstractText: abstractText,
      chineseAbstractMarkdown: '中文摘要尚未生成。',
      relatedPapers: relatedPapers,
      readMinutes: _estimateReadMinutes(abstractText),
      citations: citationCount,
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
      title: title,
      authors: authors,
      affiliations: enhancement.institutions.isEmpty
          ? affiliations
          : enhancement.institutions,
      contentKeywords:
          enhancement.concepts.isEmpty ? contentKeywords : enhancement.concepts,
      subjects: subjects,
      primarySubject: primarySubject,
      venue: venue,
      journalReference: journalReference,
      comment: comment,
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
