import 'paper.dart';

class PaperEnhancement {
  const PaperEnhancement({
    this.citationCount,
    this.institutions = const [],
    this.concepts = const [],
    this.relatedWorkIds = const [],
  });

  final int? citationCount;
  final List<String> institutions;
  final List<String> concepts;
  final List<String> relatedWorkIds;
}

extension PaperEnhancementMerge on Paper {
  Paper applyEnhancement(PaperEnhancement enhancement) {
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
