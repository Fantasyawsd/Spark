import '../domain/paper.dart';
import '../domain/paper_catalog.dart';
import '../domain/paper_repository.dart';
import 'cache/paper_cache_mapper.dart';
import 'cache/paper_cache_record.dart';
import 'cache/paper_cache_store.dart';
import 'providers/arxiv/arxiv_atom_client.dart';
import 'providers/arxiv/arxiv_atom_mapper.dart';
import 'providers/arxiv/arxiv_catalog_source.dart';

/// Reads remote papers first and keeps a usable local result when the network
/// is unavailable. The seed repository remains the final cold-start fallback.
class OfflineFirstPaperCatalogRepository implements PaperCatalogRepository {
  OfflineFirstPaperCatalogRepository({
    required ArxivCatalogSource remoteSource,
    required PaperCacheStore cacheStore,
    required PaperRepository seedRepository,
    ArxivAtomMapper mapper = const ArxivAtomMapper(),
    PaperCacheMapper cacheMapper = const PaperCacheMapper(),
    DateTime Function()? clock,
  })  : _remoteSource = remoteSource,
        _cacheStore = cacheStore,
        _seedRepository = seedRepository,
        _mapper = mapper,
        _cacheMapper = cacheMapper,
        _clock = clock ?? DateTime.now;

  final ArxivCatalogSource _remoteSource;
  final PaperCacheStore _cacheStore;
  final PaperRepository _seedRepository;
  final ArxivAtomMapper _mapper;
  final PaperCacheMapper _cacheMapper;
  final DateTime Function() _clock;

  @override
  Future<PaperPage> loadFeed(PaperFeedQuery query) async {
    final queryKey = _feedKey(query);
    try {
      final remote = await _remoteSource.loadLatest(
        category: _remoteCategory(query.category),
        offset: query.offset,
        limit: query.limit,
      );
      final papers =
          remote.entries.map(_mapper.toDomain).toList(growable: false);
      final fetchedAt = _clock().toUtc();
      await _writePage(queryKey, papers, remote.nextOffset, fetchedAt);
      return PaperPage(
        papers: papers,
        source: PaperPageSource.remote,
        nextOffset: remote.nextOffset,
        fetchedAt: fetchedAt,
      );
    } on Object catch (error) {
      final cached = await _readCachedPage(queryKey);
      if (cached != null) {
        return _stalePage(cached, error);
      }
      return _seedPage(query, error);
    }
  }

  @override
  Future<PaperPage> search(PaperSearchQuery query) async {
    final normalizedTerm = query.term.trim();
    final queryKey = _searchKey(query);
    if (normalizedTerm.isEmpty) {
      return PaperPage(papers: const [], source: PaperPageSource.seed);
    }
    try {
      final remote = await _remoteSource.search(
        term: normalizedTerm,
        offset: query.offset,
        limit: query.limit,
      );
      final papers =
          remote.entries.map(_mapper.toDomain).toList(growable: false);
      final fetchedAt = _clock().toUtc();
      await _writePage(queryKey, papers, remote.nextOffset, fetchedAt);
      return PaperPage(
        papers: papers,
        source: PaperPageSource.remote,
        nextOffset: remote.nextOffset,
        fetchedAt: fetchedAt,
      );
    } on Object catch (error) {
      final cached = await _readCachedPage(queryKey);
      if (cached != null) {
        return _stalePage(cached, error);
      }
      return _seedSearchPage(normalizedTerm, query, error);
    }
  }

  @override
  Future<Paper?> findById(String paperId) async {
    final cached = await _cacheStore.readPaper(paperId);
    if (cached != null) return _cacheMapper.toDomain(cached);
    try {
      final remote = await _remoteSource.findById(paperId);
      if (remote == null) return _seedById(paperId);
      final paper = _mapper.toDomain(remote);
      await _cacheStore.writePaper(
        _cacheMapper.toRecord(paper, cachedAt: _clock().toUtc()),
      );
      return paper;
    } on Object catch (_) {
      return _seedById(paperId);
    }
  }

  Future<void> _writePage(
    String queryKey,
    List<Paper> papers,
    int? nextOffset,
    DateTime fetchedAt,
  ) async {
    final records = papers.map(
      (paper) => _cacheMapper.toRecord(paper, cachedAt: fetchedAt),
    );
    await _cacheStore.writePage(
      page: PaperPageCacheRecord(
        queryKey: queryKey,
        paperIds: papers.map((paper) => paper.id).toList(growable: false),
        fetchedAt: fetchedAt.toIso8601String(),
        nextOffset: nextOffset,
      ),
      papers: records,
    );
  }

  Future<CachedPaperPageRecord?> _readCachedPage(String queryKey) async {
    try {
      return await _cacheStore.readPage(queryKey);
    } on Object catch (_) {
      return null;
    }
  }

  PaperPage _stalePage(CachedPaperPageRecord cached, Object error) {
    final papers =
        cached.papers.map(_cacheMapper.toDomain).toList(growable: false);
    return PaperPage(
      papers: papers,
      source: PaperPageSource.cache,
      nextOffset: cached.page.nextOffset,
      isStale: true,
      isOffline: true,
      error: _catalogError(error),
      fetchedAt: DateTime.parse(cached.page.fetchedAt).toUtc(),
    );
  }

  PaperPage _seedPage(PaperFeedQuery query, Object error) {
    final papers = _seedRepository.getAll();
    final filtered = _filterSeed(papers, query.category);
    return _sliceSeed(filtered, query.offset, query.limit, error);
  }

  PaperPage _seedSearchPage(String term, PaperSearchQuery query, Object error) {
    final normalized = term.toLowerCase();
    final matches = _seedRepository.getAll().where((paper) {
      final text = [
        paper.title,
        paper.content.originalAbstractMarkdown,
        paper.venue,
        ...paper.authors,
        ...paper.topics,
      ].join(' ').toLowerCase();
      return text.contains(normalized);
    }).toList(growable: false);
    return _sliceSeed(matches, query.offset, query.limit, error);
  }

  PaperPage _sliceSeed(
    List<Paper> papers,
    int offset,
    int limit,
    Object error,
  ) {
    if (offset >= papers.length) {
      return PaperPage(
        papers: const [],
        source: PaperPageSource.seed,
        error: _catalogError(error),
      );
    }
    final end = (offset + limit).clamp(0, papers.length);
    return PaperPage(
      papers: papers.sublist(offset, end),
      source: PaperPageSource.seed,
      nextOffset: end < papers.length ? end : null,
      isOffline: true,
      error: _catalogError(error),
    );
  }

  List<Paper> _filterSeed(List<Paper> papers, String? category) {
    final normalized = category?.trim();
    if (normalized == null || normalized.isEmpty || normalized == '全部') {
      return papers;
    }
    return papers.where((paper) {
      final text =
          [paper.title, paper.venue, ...paper.topics].join(' ').toLowerCase();
      return text.contains(normalized.toLowerCase());
    }).toList(growable: false);
  }

  Paper? _seedById(String paperId) {
    for (final paper in _seedRepository.getAll()) {
      if (paper.id == paperId || paper.arxivId == paperId) return paper;
    }
    return null;
  }

  String? _remoteCategory(String? category) {
    final normalized = category?.trim();
    if (normalized == null || normalized.isEmpty || normalized == '全部') {
      return null;
    }
    return normalized;
  }

  static String _feedKey(PaperFeedQuery query) =>
      'feed|category=${query.category?.trim() ?? ''}|offset=${query.offset}|limit=${query.limit}';

  static String _searchKey(PaperSearchQuery query) =>
      'search|term=${query.term.trim().toLowerCase()}|offset=${query.offset}|limit=${query.limit}';

  static PaperCatalogError _catalogError(Object error) {
    if (error is ArxivApiException) {
      final kind = switch (error.kind) {
        ArxivApiErrorKind.timeout => PaperCatalogErrorKind.timeout,
        ArxivApiErrorKind.invalidResponse =>
          PaperCatalogErrorKind.invalidResponse,
        ArxivApiErrorKind.http => PaperCatalogErrorKind.network,
      };
      final message = switch (error.kind) {
        ArxivApiErrorKind.timeout => 'arXiv 响应超时，已显示本地数据。',
        ArxivApiErrorKind.invalidResponse => 'arXiv 数据暂时无法读取，已显示本地数据。',
        ArxivApiErrorKind.http => 'arXiv 服务暂时不可用，已显示本地数据。',
      };
      return PaperCatalogError(kind: kind, message: message);
    }
    return const PaperCatalogError(
      kind: PaperCatalogErrorKind.unavailable,
      message: '远程论文暂时不可用，已显示本地数据。',
    );
  }
}
