import '../../domain/paper.dart';
import 'paper_cache_record.dart';
import '../paper_json_value_reader.dart';

class PaperCacheMapper {
  const PaperCacheMapper();

  PaperCacheRecord toRecord(Paper paper, {required DateTime cachedAt}) {
    return PaperCacheRecord(
      id: paper.id,
      title: paper.title,
      authors: paper.authors,
      affiliations: paper.affiliations,
      contentKeywords: paper.contentKeywords,
      subjects: paper.subjects,
      primarySubject: paper.primarySubject,
      venue: paper.venue,
      journalReference: paper.journalReference,
      comment: paper.comment,
      abstractMarkdown: paper.content.originalAbstractMarkdown,
      chineseAbstractMarkdown: paper.content.chineseAbstractMarkdown,
      relatedPapers: paper.relatedPapers
          .map(
            (related) => RelatedPaperCacheRecord(
              id: related.id,
              title: related.title,
              venue: related.venue,
              relation: related.relation,
            ),
          )
          .toList(growable: false),
      readMinutes: paper.readMinutes,
      citations: paper.metrics.citations,
      likes: paper.metrics.likes,
      comments: paper.metrics.comments,
      saves: paper.metrics.saves,
      shares: paper.metrics.shares,
      arxivId: paper.arxivId,
      doi: paper.doi,
      paperUrl: paper.paperUrl,
      pdfUrl: paper.pdfUrl,
      publishedAt: paper.publishedAt?.toUtc().toIso8601String(),
      updatedAt: paper.updatedAt?.toUtc().toIso8601String(),
      license: paper.license,
      source: paper.source,
      cachedAt: cachedAt.toUtc().toIso8601String(),
    );
  }

  Paper toDomain(PaperCacheRecord record) {
    return Paper(
      id: record.id,
      title: record.title,
      authors: record.authors,
      affiliations: record.affiliations,
      contentKeywords: record.contentKeywords,
      subjects: record.subjects,
      primarySubject: record.primarySubject,
      venue: record.venue,
      journalReference: record.journalReference,
      comment: record.comment,
      abstractText: record.abstractMarkdown,
      chineseAbstractMarkdown: record.chineseAbstractMarkdown,
      relatedPapers: record.relatedPapers
          .map(
            (related) => RelatedPaper(
              id: related.id,
              title: related.title,
              venue: related.venue,
              relation: related.relation,
            ),
          )
          .toList(growable: false),
      readMinutes: record.readMinutes,
      citations: record.citations,
      likes: record.likes,
      comments: record.comments,
      saves: record.saves,
      shares: record.shares,
      arxivId: record.arxivId,
      doi: record.doi,
      paperUrl: record.paperUrl,
      pdfUrl: record.pdfUrl,
      publishedAt: _optionalDate(record.publishedAt, 'publishedAt'),
      updatedAt: _optionalDate(record.updatedAt, 'updatedAt'),
      license: record.license,
      source: record.source,
    );
  }

  DateTime cachedAt(PaperCacheRecord record) {
    return _requiredDate(record.cachedAt, 'cachedAt');
  }

  static Map<String, dynamic> snapshotToJson(
    PaperCacheSnapshotRecord snapshot,
  ) {
    return {
      'papers': snapshot.papers.map(
        (id, record) => MapEntry(id, _paperToJson(record)),
      ),
      'pages': snapshot.pages.map(
        (key, record) => MapEntry(key, _pageToJson(record)),
      ),
    };
  }

  static PaperCacheSnapshotRecord snapshotFromJson(Map<String, dynamic> json) {
    final papersJson = _requiredMap(json, 'papers');
    final pagesJson = _requiredMap(json, 'pages');
    final papers = papersJson.map(
      (id, value) => MapEntry(
        id,
        _paperFromJson(
          PaperJsonValueReader.stringMapValue(value, 'papers.$id'),
        ),
      ),
    );
    final pages = pagesJson.map(
      (key, value) => MapEntry(
        key,
        _pageFromJson(PaperJsonValueReader.stringMapValue(value, 'pages.$key')),
      ),
    );
    for (final entry in pages.entries) {
      if (entry.key != entry.value.queryKey) {
        throw FormatException('论文缓存页键不一致：${entry.key}');
      }
      for (final paperId in entry.value.paperIds) {
        if (!papers.containsKey(paperId)) {
          throw FormatException('论文缓存页引用了不存在的论文：$paperId');
        }
      }
    }
    return PaperCacheSnapshotRecord(papers: papers, pages: pages);
  }

  static void validatePayload(Object? payload) {
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('论文缓存必须是对象。');
    }
    snapshotFromJson(payload);
  }

  static Map<String, dynamic> _paperToJson(PaperCacheRecord record) {
    return {
      'id': record.id,
      'title': record.title,
      'authors': record.authors,
      'affiliations': record.affiliations,
      'contentKeywords': record.contentKeywords,
      'subjects': record.subjects,
      'primarySubject': record.primarySubject,
      'venue': record.venue,
      'journalReference': record.journalReference,
      'comment': record.comment,
      'abstractMarkdown': record.abstractMarkdown,
      'chineseAbstractMarkdown': record.chineseAbstractMarkdown,
      'relatedPapers': record.relatedPapers
          .map(
            (related) => {
              'id': related.id,
              'title': related.title,
              'venue': related.venue,
              'relation': related.relation,
            },
          )
          .toList(growable: false),
      'readMinutes': record.readMinutes,
      'citations': record.citations,
      'likes': record.likes,
      'comments': record.comments,
      'saves': record.saves,
      'shares': record.shares,
      'arxivId': record.arxivId,
      'doi': record.doi,
      'paperUrl': record.paperUrl,
      'pdfUrl': record.pdfUrl,
      'publishedAt': record.publishedAt,
      'updatedAt': record.updatedAt,
      'license': record.license,
      'source': record.source,
      'cachedAt': record.cachedAt,
    };
  }

  static PaperCacheRecord _paperFromJson(Map<String, dynamic> json) {
    return PaperCacheRecord(
      id: PaperJsonValueReader.requiredNonEmptyString(json, 'id'),
      title: PaperJsonValueReader.requiredNonEmptyString(json, 'title'),
      authors: PaperJsonValueReader.requiredStringList(json, 'authors'),
      affiliations: PaperJsonValueReader.requiredStringList(
        json,
        'affiliations',
      ),
      contentKeywords: PaperJsonValueReader.requiredStringList(
        json,
        'contentKeywords',
      ),
      subjects: PaperJsonValueReader.requiredStringList(json, 'subjects'),
      primarySubject: PaperJsonValueReader.nullableString(
        json,
        'primarySubject',
      ),
      venue: PaperJsonValueReader.nullableString(json, 'venue'),
      journalReference: PaperJsonValueReader.nullableString(
        json,
        'journalReference',
      ),
      comment: PaperJsonValueReader.nullableString(json, 'comment'),
      abstractMarkdown: PaperJsonValueReader.requiredNonEmptyString(
        json,
        'abstractMarkdown',
      ),
      chineseAbstractMarkdown: PaperJsonValueReader.requiredNonEmptyString(
        json,
        'chineseAbstractMarkdown',
      ),
      relatedPapers:
          PaperJsonValueReader.list(json, 'relatedPapers').map((value) {
        final related = PaperJsonValueReader.stringMapValue(
          value,
          'relatedPapers',
        );
        return RelatedPaperCacheRecord(
          id: PaperJsonValueReader.requiredNonEmptyString(related, 'id'),
          title: PaperJsonValueReader.requiredNonEmptyString(
            related,
            'title',
          ),
          venue: PaperJsonValueReader.nullableString(related, 'venue'),
          relation: PaperJsonValueReader.requiredNonEmptyString(
            related,
            'relation',
          ),
        );
      }).toList(growable: false),
      readMinutes: PaperJsonValueReader.requiredInt(json, 'readMinutes'),
      citations: PaperJsonValueReader.nullableInt(json, 'citations'),
      likes: PaperJsonValueReader.requiredInt(json, 'likes'),
      comments: PaperJsonValueReader.requiredInt(json, 'comments'),
      saves: PaperJsonValueReader.requiredInt(json, 'saves'),
      shares: PaperJsonValueReader.requiredInt(json, 'shares'),
      arxivId: PaperJsonValueReader.nullableString(json, 'arxivId'),
      doi: PaperJsonValueReader.nullableString(json, 'doi'),
      paperUrl: PaperJsonValueReader.nullableString(json, 'paperUrl'),
      pdfUrl: PaperJsonValueReader.nullableString(json, 'pdfUrl'),
      publishedAt: PaperJsonValueReader.nullableString(json, 'publishedAt'),
      updatedAt: PaperJsonValueReader.nullableString(json, 'updatedAt'),
      license: PaperJsonValueReader.nullableString(json, 'license'),
      source: PaperJsonValueReader.requiredNonEmptyString(json, 'source'),
      cachedAt: PaperJsonValueReader.requiredNonEmptyString(json, 'cachedAt'),
    );
  }

  static Map<String, dynamic> _pageToJson(PaperPageCacheRecord record) {
    return {
      'queryKey': record.queryKey,
      'paperIds': record.paperIds,
      'fetchedAt': record.fetchedAt,
      'nextOffset': record.nextOffset,
    };
  }

  static PaperPageCacheRecord _pageFromJson(Map<String, dynamic> json) {
    final nextOffset = json['nextOffset'];
    if (nextOffset != null && nextOffset is! int) {
      throw const FormatException('论文缓存 nextOffset 必须是整数或 null。');
    }
    final fetchedAt = PaperJsonValueReader.requiredNonEmptyString(
      json,
      'fetchedAt',
    );
    _requiredDate(fetchedAt, 'fetchedAt');
    return PaperPageCacheRecord(
      queryKey: PaperJsonValueReader.requiredNonEmptyString(json, 'queryKey'),
      paperIds: PaperJsonValueReader.requiredStringList(json, 'paperIds'),
      fetchedAt: fetchedAt,
      nextOffset: nextOffset as int?,
    );
  }

  static Map<String, dynamic> _requiredMap(
    Map<String, dynamic> json,
    String key,
  ) {
    return PaperJsonValueReader.stringMapValue(json[key], key);
  }

  static DateTime _requiredDate(String value, String field) {
    final date = DateTime.tryParse(value);
    if (date == null) throw FormatException('论文缓存日期字段 $field 无效。');
    return date.toUtc();
  }

  static DateTime? _optionalDate(String? value, String field) {
    return value == null ? null : _requiredDate(value, field);
  }
}
