import '../../../domain/paper.dart';
import 'arxiv_id.dart';
import 'arxiv_paper_dto.dart';

class ArxivPaperMapper {
  const ArxivPaperMapper();

  Paper toDomain(
    ArxivPaperDto dto, {
    List<RelatedPaper> relatedPapers = const [],
  }) {
    final id = normalizeArxivId(dto.id);
    final subjects = <String>{
      ...dto.categories.where((category) => category.trim().isNotEmpty),
      if (dto.primaryCategory case final category?) category,
    }.toList(growable: false);
    return Paper(
      id: id,
      title: dto.title,
      authors: dto.authors,
      affiliations: dto.affiliations
          .where((affiliation) => affiliation.trim().isNotEmpty)
          .toList(growable: false),
      subjects: subjects,
      primarySubject: dto.primaryCategory,
      journalReference: dto.journalReference,
      comment: dto.comment,
      abstractText: dto.summary,
      chineseAbstractMarkdown: '中文摘要尚未生成。',
      relatedPapers: relatedPapers,
      readMinutes: _estimateReadMinutes(dto.summary),
      arxivId: id,
      doi: dto.doi,
      paperUrl: dto.paperUrl ?? 'https://arxiv.org/abs/$id',
      pdfUrl: dto.pdfUrl ?? 'https://arxiv.org/pdf/$id',
      publishedAt: dto.publishedAt,
      updatedAt: dto.updatedAt,
      license: dto.license,
      source: 'arxiv',
    );
  }

  static int _estimateReadMinutes(String text) {
    final words = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
    return (words / 180).ceil().clamp(1, 60);
  }
}
