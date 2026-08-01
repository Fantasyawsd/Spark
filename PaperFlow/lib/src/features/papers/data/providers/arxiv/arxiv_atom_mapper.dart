import '../../../domain/paper.dart';
import 'arxiv_atom_dto.dart';
import 'arxiv_id.dart';

class ArxivAtomMapper {
  const ArxivAtomMapper();

  Paper toDomain(ArxivAtomPaperDto dto) {
    final id = normalizeArxivId(dto.id);
    final topics = <String>{
      ...dto.categories,
      if (dto.primaryCategory case final category?) category,
    }.toList(growable: false);
    return Paper(
      id: id,
      venue: dto.journalReference ?? 'arXiv',
      title: dto.title,
      authors: dto.authors,
      firstAffiliation: dto.affiliations.firstOrNull ?? 'arXiv',
      topics: topics.isEmpty ? const ['arXiv'] : topics,
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
