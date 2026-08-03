import '../../../domain/paper.dart';
import 'arxiv_atom_dto.dart';
import 'arxiv_id.dart';

class ArxivAtomMapper {
  const ArxivAtomMapper();

  Paper toDomain(ArxivAtomPaperDto dto) {
    final id = normalizeArxivId(dto.id);
    final subjects = <String>{
      ...dto.categories,
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
      readMinutes: _estimateReadMinutes(dto.summary),
      arxivId: id,
      doi: dto.doi,
      paperUrl: dto.paperUrl,
      pdfUrl: dto.pdfUrl,
      publishedAt: dto.publishedAt,
      updatedAt: dto.updatedAt,
      license: dto.license,
      source: 'arxiv',
    );
  }

  int _estimateReadMinutes(String text) {
    final words = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
    return (words / 180).ceil().clamp(1, 60);
  }
}
