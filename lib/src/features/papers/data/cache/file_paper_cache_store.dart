import '../../../../core/storage/local_json_store.dart';
import '../../../../core/storage/versioned_local_json_store.dart';
import 'paper_cache_mapper.dart';
import 'paper_cache_record.dart';
import 'paper_cache_store.dart';

class FilePaperCacheStore implements PaperCacheStore {
  FilePaperCacheStore({
    LocalJsonStore? store,
    DateTime Function()? clock,
    PaperCachePolicy policy = const PaperCachePolicy(),
  })  : _clock = clock ?? DateTime.now,
        _policy = policy,
        _store = VersionedLocalJsonStore(
          store ?? LocalJsonStore(fileName: 'paper_catalog_cache.json'),
          schemaId: 'papers.catalog-cache',
          schemaVersion: 2,
          migrations: const {1: _migrateSnapshotV1ToV2},
          validatePayload: PaperCacheMapper.validatePayload,
        );

  static Object? _migrateSnapshotV1ToV2(Object? payload) {
    if (payload is! Map<String, dynamic>) return payload;
    final papers = payload['papers'];
    if (papers is! Map) return payload;
    final migratedPapers = papers.map(
      (id, paper) => MapEntry(
        id,
        paper is Map<String, dynamic> ? _migratePaperV1ToV2(paper) : paper,
      ),
    );
    return Map<String, dynamic>.from(payload)..['papers'] = migratedPapers;
  }

  static Map<String, dynamic> _migratePaperV1ToV2(Map<String, dynamic> paper) {
    final migrated = Map<String, dynamic>.from(paper);
    final source = migrated['source'];
    final isArxiv = source == 'arxiv';

    final firstAffiliation = migrated.remove('firstAffiliation');
    final affiliation =
        firstAffiliation is String ? firstAffiliation.trim() : '';
    migrated['affiliations'] =
        affiliation.isEmpty || affiliation.toLowerCase() == 'arxiv'
            ? const <String>[]
            : <String>[affiliation];

    final topics = migrated.remove('topics');
    final topicList =
        topics is List ? topics.whereType<String>().toList() : <String>[];
    if (isArxiv) {
      migrated['subjects'] = topicList;
      migrated['contentKeywords'] = const <String>[];
    } else {
      migrated['subjects'] = const <String>[];
      migrated['contentKeywords'] = topicList;
    }
    migrated['primarySubject'] = null;

    final oldVenue = migrated['venue'];
    if (isArxiv) {
      // v1 用 'arXiv' 顶替缺失的 venue/journalReference，迁移时还原未知语义。
      migrated['journalReference'] =
          oldVenue is String && oldVenue != 'arXiv' ? oldVenue : null;
      migrated['venue'] = null;
      if (migrated['citations'] == 0) {
        migrated['citations'] = null;
      }
    } else {
      migrated['journalReference'] = null;
    }
    migrated['comment'] = null;

    final relatedPapers = migrated['relatedPapers'];
    if (relatedPapers is List) {
      migrated['relatedPapers'] = relatedPapers.map((related) {
        if (related is Map<String, dynamic> && related['venue'] == 'arXiv') {
          return Map<String, dynamic>.from(related)..['venue'] = null;
        }
        return related;
      }).toList(growable: false);
    }
    return migrated;
  }

  final VersionedLocalJsonStore _store;
  final DateTime Function() _clock;
  final PaperCachePolicy _policy;

  @override
  Future<CachedPaperPageRecord?> readPage(String queryKey) async {
    final snapshot = await _readSnapshot();
    final page = snapshot.pages[queryKey];
    if (page == null) return null;
    return CachedPaperPageRecord(
      page: page,
      papers: page.paperIds
          .map((paperId) => snapshot.papers[paperId]!)
          .toList(growable: false),
    );
  }

  @override
  Future<PaperCacheRecord?> readPaper(String paperId) async {
    return (await _readSnapshot()).papers[paperId];
  }

  @override
  Future<void> writePage({
    required PaperPageCacheRecord page,
    required Iterable<PaperCacheRecord> papers,
  }) {
    return _store.updateMap((current) {
      final snapshot = _snapshotFromNullableJson(current);
      final updatedPapers = Map<String, PaperCacheRecord>.of(snapshot.papers);
      for (final paper in papers) {
        updatedPapers[paper.id] = paper;
      }
      final updatedPages = Map<String, PaperPageCacheRecord>.of(snapshot.pages)
        ..[page.queryKey] = page;
      return PaperCacheMapper.snapshotToJson(
        _bounded(
          PaperCacheSnapshotRecord(
            papers: updatedPapers,
            pages: updatedPages,
          ),
        ),
      );
    });
  }

  @override
  Future<void> writePaper(PaperCacheRecord paper) {
    return _store.updateMap((current) {
      final snapshot = _snapshotFromNullableJson(current);
      return PaperCacheMapper.snapshotToJson(
        _bounded(
          PaperCacheSnapshotRecord(
            papers: Map<String, PaperCacheRecord>.of(snapshot.papers)
              ..[paper.id] = paper,
            pages: snapshot.pages,
          ),
        ),
      );
    });
  }

  Future<PaperCacheSnapshotRecord> _readSnapshot() async {
    return _snapshotFromNullableJson(await _store.readMap());
  }

  static PaperCacheSnapshotRecord _snapshotFromNullableJson(
    Map<String, dynamic>? json,
  ) {
    return json == null
        ? const PaperCacheSnapshotRecord.empty()
        : PaperCacheMapper.snapshotFromJson(json);
  }

  PaperCacheSnapshotRecord _bounded(PaperCacheSnapshotRecord snapshot) {
    if (_policy.retention <= Duration.zero) {
      throw ArgumentError.value(
        _policy.retention,
        'policy.retention',
        'must be positive',
      );
    }
    final cutoff = _clock().toUtc().subtract(_policy.retention);
    final eligiblePaperIds = <String>{
      for (final paper in snapshot.papers.values)
        if (!_cachedAt(paper).isBefore(cutoff)) paper.id,
    };
    final pages = snapshot.pages.values.where((page) {
      return !_fetchedAt(page).isBefore(cutoff) &&
          page.paperIds.every(eligiblePaperIds.contains);
    }).toList(growable: true)
      ..sort(_comparePagesNewestFirst);
    if (pages.length > _policy.maxPages) {
      pages.removeRange(_policy.maxPages, pages.length);
    }

    var referencedIds = _referencedPaperIds(pages);
    while (pages.isNotEmpty && referencedIds.length > _policy.maxPapers) {
      pages.removeLast();
      referencedIds = _referencedPaperIds(pages);
    }

    final papers = <String, PaperCacheRecord>{};
    for (final paperId in referencedIds) {
      final paper = snapshot.papers[paperId];
      if (paper != null) papers[paperId] = paper;
    }
    final remaining = snapshot.papers.values
        .where(
          (paper) =>
              eligiblePaperIds.contains(paper.id) &&
              !papers.containsKey(paper.id),
        )
        .toList(growable: false)
      ..sort(_comparePapersNewestFirst);
    for (final paper in remaining) {
      if (papers.length >= _policy.maxPapers) break;
      papers[paper.id] = paper;
    }

    return PaperCacheSnapshotRecord(
      papers: papers,
      pages: {for (final page in pages) page.queryKey: page},
    );
  }

  static Set<String> _referencedPaperIds(
    Iterable<PaperPageCacheRecord> pages,
  ) {
    return {for (final page in pages) ...page.paperIds};
  }

  static int _comparePagesNewestFirst(
    PaperPageCacheRecord left,
    PaperPageCacheRecord right,
  ) {
    final byDate = _fetchedAt(right).compareTo(_fetchedAt(left));
    return byDate != 0 ? byDate : left.queryKey.compareTo(right.queryKey);
  }

  static int _comparePapersNewestFirst(
    PaperCacheRecord left,
    PaperCacheRecord right,
  ) {
    final byDate = _cachedAt(right).compareTo(_cachedAt(left));
    return byDate != 0 ? byDate : left.id.compareTo(right.id);
  }

  static DateTime _fetchedAt(PaperPageCacheRecord page) {
    return DateTime.parse(page.fetchedAt).toUtc();
  }

  static DateTime _cachedAt(PaperCacheRecord paper) {
    return DateTime.parse(paper.cachedAt).toUtc();
  }
}
