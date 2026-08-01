import '../../domain/paper.dart';
import 'paper_cache_record.dart';

class PaperCacheMapper {
  const PaperCacheMapper();

  PaperCacheRecord toRecord(Paper paper, {required DateTime cachedAt}) {
    return PaperCacheRecord(
      id: paper.id,
      venue: paper.venue,
      title: paper.title,
      authors: paper.authors,
      firstAffiliation: paper.firstAffiliation,
      topics: paper.topics,
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
      venue: record.venue,
      title: record.title,
      authors: record.authors,
      firstAffiliation: record.firstAffiliation,
      topics: record.topics,
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

  static PaperCacheSnapshotRecord snapshotFromJson(
    Map<String, dynamic> json,
  ) {
    final papersJson = _requiredMap(json, 'papers');
    final pagesJson = _requiredMap(json, 'pages');
    final papers = papersJson.map(
      (id, value) => MapEntry(
        id,
        _paperFromJson(_asMap(value, 'papers.$id')),
      ),
    );
    final pages = pagesJson.map(
      (key, value) => MapEntry(
        key,
        _pageFromJson(_asMap(value, 'pages.$key')),
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
      'venue': record.venue,
      'title': record.title,
      'authors': record.authors,
      'firstAffiliation': record.firstAffiliation,
      'topics': record.topics,
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
      id: _requiredString(json, 'id'),
      venue: _requiredString(json, 'venue'),
      title: _requiredString(json, 'title'),
      authors: _stringList(json, 'authors'),
      firstAffiliation: _requiredString(json, 'firstAffiliation'),
      topics: _stringList(json, 'topics'),
      abstractMarkdown: _requiredString(json, 'abstractMarkdown'),
      chineseAbstractMarkdown: _requiredString(json, 'chineseAbstractMarkdown'),
      relatedPapers: _list(json, 'relatedPapers').map((value) {
        final related = _asMap(value, 'relatedPapers');
        return RelatedPaperCacheRecord(
          id: _requiredString(related, 'id'),
          title: _requiredString(related, 'title'),
          venue: _requiredString(related, 'venue'),
          relation: _requiredString(related, 'relation'),
        );
      }).toList(growable: false),
      readMinutes: _requiredInt(json, 'readMinutes'),
      citations: _requiredInt(json, 'citations'),
      likes: _requiredInt(json, 'likes'),
      comments: _requiredInt(json, 'comments'),
      saves: _requiredInt(json, 'saves'),
      shares: _requiredInt(json, 'shares'),
      arxivId: _optionalString(json, 'arxivId'),
      doi: _optionalString(json, 'doi'),
      paperUrl: _optionalString(json, 'paperUrl'),
      pdfUrl: _optionalString(json, 'pdfUrl'),
      publishedAt: _optionalString(json, 'publishedAt'),
      updatedAt: _optionalString(json, 'updatedAt'),
      license: _optionalString(json, 'license'),
      source: _requiredString(json, 'source'),
      cachedAt: _requiredString(json, 'cachedAt'),
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
    final fetchedAt = _requiredString(json, 'fetchedAt');
    _requiredDate(fetchedAt, 'fetchedAt');
    return PaperPageCacheRecord(
      queryKey: _requiredString(json, 'queryKey'),
      paperIds: _stringList(json, 'paperIds'),
      fetchedAt: fetchedAt,
      nextOffset: nextOffset as int?,
    );
  }

  static Map<String, dynamic> _requiredMap(
    Map<String, dynamic> json,
    String key,
  ) {
    return _asMap(json[key], key);
  }

  static Map<String, dynamic> _asMap(Object? value, String field) {
    if (value is! Map) throw FormatException('论文缓存字段 $field 必须是对象。');
    return Map<String, dynamic>.from(value);
  }

  static List<dynamic> _list(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! List) throw FormatException('论文缓存字段 $key 必须是数组。');
    return List<dynamic>.from(value);
  }

  static List<String> _stringList(Map<String, dynamic> json, String key) {
    final values = _list(json, key);
    if (values.any((value) => value is! String)) {
      throw FormatException('论文缓存字段 $key 必须是字符串数组。');
    }
    return values.cast<String>();
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('论文缓存字段 $key 必须是非空字符串。');
    }
    return value;
  }

  static String? _optionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String) throw FormatException('论文缓存字段 $key 必须是字符串。');
    return value;
  }

  static int _requiredInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! int) throw FormatException('论文缓存字段 $key 必须是整数。');
    return value;
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
