import '../../../domain/paper.dart';
import 'paper_api_dto.dart';

final class PaperApiMapper {
  const PaperApiMapper();

  Paper toDomain(PaperApiPaperDto dto) {
    final abstractText = dto.abstractText ?? '';
    final arxivId = dto.externalIds['arxiv_id'];
    return Paper(
      id: dto.paperId,
      title: dto.title,
      authors: dto.authors,
      affiliations: _stringList(dto.metadata['affiliations']),
      subjects: dto.subjects,
      primarySubject: dto.subjects.firstOrNull,
      venue: _string(dto.metadata['venue_name']),
      journalReference: _string(dto.metadata['journal_reference']),
      comment: _string(dto.metadata['comment']),
      abstractText: abstractText,
      chineseAbstractMarkdown: '中文摘要尚未生成。',
      readMinutes: _estimateReadMinutes(abstractText),
      citations: _citationCount(dto.signals),
      webTrendReason: _webHeatReason(dto.signals),
      webTrendTopics: _webHeatTopics(dto.signals),
      arxivId: arxivId,
      doi: dto.externalIds['doi'],
      paperUrl: _string(dto.metadata['abs_url']) ??
          (arxivId == null ? null : 'https://arxiv.org/abs/$arxivId'),
      pdfUrl: _string(dto.metadata['pdf_url']) ??
          (arxivId == null ? null : 'https://arxiv.org/pdf/$arxivId'),
      publishedAt: dto.publishedAt,
      updatedAt: dto.updatedAt,
      license: _string(dto.metadata['license']),
      source: dto.discoverySources.firstOrNull ?? 'spark-api',
      personalizationScore: dto.personalizationScore,
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

  static int? _citationCount(Map<String, Map<String, dynamic>> signals) {
    for (final source in const ['openalex', 'semantic_scholar']) {
      final value = signals[source]?['citation_count'];
      if (value is int) return value;
      if (value is num) return value.toInt();
    }
    return null;
  }

  static String? _webHeatReason(Map<String, Map<String, dynamic>> signals) {
    return _string(signals['web_heat']?['trend_reason']);
  }

  static List<String> _webHeatTopics(
    Map<String, Map<String, dynamic>> signals,
  ) {
    return _stringList(signals['web_heat']?['trend_topics']);
  }

  static String? _string(Object? value) {
    if (value is! String) return null;
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
