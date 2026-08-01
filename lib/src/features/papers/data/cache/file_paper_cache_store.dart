import '../../../../core/storage/local_json_store.dart';
import '../../../../core/storage/versioned_local_json_store.dart';
import 'paper_cache_mapper.dart';
import 'paper_cache_record.dart';
import 'paper_cache_store.dart';

class FilePaperCacheStore implements PaperCacheStore {
  FilePaperCacheStore({LocalJsonStore? store})
      : _store = VersionedLocalJsonStore(
          store ?? LocalJsonStore(fileName: 'paper_catalog_cache.json'),
          schemaId: 'papers.catalog-cache',
          validatePayload: PaperCacheMapper.validatePayload,
        );

  final VersionedLocalJsonStore _store;

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
        PaperCacheSnapshotRecord(
          papers: updatedPapers,
          pages: updatedPages,
        ),
      );
    });
  }

  @override
  Future<void> writePaper(PaperCacheRecord paper) {
    return _store.updateMap((current) {
      final snapshot = _snapshotFromNullableJson(current);
      return PaperCacheMapper.snapshotToJson(
        PaperCacheSnapshotRecord(
          papers: Map<String, PaperCacheRecord>.of(snapshot.papers)
            ..[paper.id] = paper,
          pages: snapshot.pages,
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
}
