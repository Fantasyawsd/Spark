import '../../../core/diagnostics/diagnostics.dart';
import '../domain/paper.dart';
import '../domain/paper_catalog.dart';
import 'providers/paper_api/paper_api_client.dart';
import 'providers/paper_api/paper_api_mapper.dart';

final class PaperApiCatalogRepository implements PaperCatalogRepository {
  PaperApiCatalogRepository({
    required PaperApiSource remoteSource,
    required PaperCatalogRepository fallbackRepository,
    PaperApiMapper mapper = const PaperApiMapper(),
    DateTime Function()? clock,
  })  : _remoteSource = remoteSource,
        _fallbackRepository = fallbackRepository,
        _mapper = mapper,
        _clock = clock ?? DateTime.now;

  final PaperApiSource _remoteSource;
  final PaperCatalogRepository _fallbackRepository;
  final PaperApiMapper _mapper;
  final DateTime Function() _clock;

  @override
  Future<PaperPage> loadFeed(PaperFeedQuery query) async {
    try {
      final remote = await _remoteSource.loadFeed(query);
      final papers = remote.items
          .map(_mapper.toDomain)
          .where((paper) => query.timeRange.includes(paper, now: _clock()))
          .toList(growable: false);
      return PaperPage(
        papers: papers,
        source: PaperPageSource.paperApi,
        nextOffset: remote.nextCursor == null
            ? null
            : query.offset + remote.items.length,
        nextCursor: remote.nextCursor,
        fetchedAt: _clock().toUtc(),
      );
    } on Object catch (error, stackTrace) {
      SparkDiagnostics.reportUnexpected(
        operation: SparkDiagnosticOperation.paperCatalogApiLoadFeed,
        error: error,
        stackTrace: stackTrace,
        severity: SparkDiagnosticSeverity.warning,
      );
      final fallback = await _fallbackRepository.loadFeed(query);
      return PaperPage(
        papers: fallback.papers,
        source: fallback.source,
        nextOffset: fallback.nextOffset,
        nextCursor: fallback.nextCursor,
        isStale: fallback.isStale,
        isOffline: fallback.isOffline,
        error: _catalogError(error),
        fetchedAt: fallback.fetchedAt,
      );
    }
  }

  @override
  Future<PaperPage> search(PaperSearchQuery query) =>
      _fallbackRepository.search(query);

  @override
  Future<Paper?> findById(String paperId) async {
    try {
      final remote = await _remoteSource.findById(paperId);
      if (remote != null) return _mapper.toDomain(remote);
    } on Object catch (error, stackTrace) {
      SparkDiagnostics.reportUnexpected(
        operation: SparkDiagnosticOperation.paperCatalogApiFindById,
        error: error,
        stackTrace: stackTrace,
        severity: SparkDiagnosticSeverity.warning,
      );
      // Detail lookup retains the existing catalog as a transparent fallback.
    }
    return _fallbackRepository.findById(paperId);
  }

  static PaperCatalogError _catalogError(Object error) {
    if (error is PaperApiException) {
      final kind = switch (error.kind) {
        PaperApiErrorKind.timeout => PaperCatalogErrorKind.timeout,
        PaperApiErrorKind.invalidResponse =>
          PaperCatalogErrorKind.invalidResponse,
        PaperApiErrorKind.network ||
        PaperApiErrorKind.http =>
          PaperCatalogErrorKind.network,
      };
      return PaperCatalogError(
        kind: kind,
        message: '本地 Paper API 不可用，已切换备用论文目录。',
      );
    }
    return const PaperCatalogError(
      kind: PaperCatalogErrorKind.unavailable,
      message: '本地 Paper API 不可用，已切换备用论文目录。',
    );
  }
}
