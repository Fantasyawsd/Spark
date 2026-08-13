import 'dart:async';
import 'dart:developer' as developer;

enum SparkDiagnosticSeverity {
  warning(900),
  error(1000);

  const SparkDiagnosticSeverity(this.developerLogLevel);

  final int developerLogLevel;
}

/// 固定的诊断操作标识，避免调用方把请求内容或用户数据拼进日志字段。
enum SparkDiagnosticOperation {
  flutterFramework('flutter.framework'),
  flutterPlatform('flutter.platform'),
  dartUnhandled('dart.unhandled'),
  paperFeedRefresh('papers.feed.refresh'),
  paperFeedLoadMore('papers.feed.load_more'),
  paperSearchHistoryLoad('search.history.load'),
  paperSearchHistorySave('search.history.save'),
  paperSearchFindById('search.catalog.find_by_id'),
  paperSearchLoad('search.catalog.load'),
  paperSearchLoadMore('search.catalog.load_more'),
  paperCatalogArxivLoadFeed('papers.catalog.arxiv.load_feed'),
  paperCatalogArxivSearch('papers.catalog.arxiv.search'),
  paperCatalogArxivFindById('papers.catalog.arxiv.find_by_id'),
  paperCatalogCacheReadPaper('papers.catalog.cache.read_paper'),
  paperCatalogCacheWritePaper('papers.catalog.cache.write_paper'),
  paperCatalogCacheReadPage('papers.catalog.cache.read_page'),
  paperCatalogCacheWritePage('papers.catalog.cache.write_page'),
  paperCatalogApiLoadFeed('papers.catalog.api.load_feed'),
  paperCatalogApiFindById('papers.catalog.api.find_by_id');

  const SparkDiagnosticOperation(this.code);

  final String code;
}

final class SparkDiagnosticEvent {
  const SparkDiagnosticEvent({
    required this.operation,
    required this.severity,
    required this.errorType,
    required this.stackTrace,
  });

  final SparkDiagnosticOperation operation;
  final SparkDiagnosticSeverity severity;
  final String errorType;
  final StackTrace stackTrace;

  String get summary => 'unexpected_error type=$errorType';
}

typedef SparkDiagnosticSink = void Function(SparkDiagnosticEvent event);

/// 只记录定位故障所需的最小元数据，不记录异常文本或任意上下文 payload。
abstract final class SparkDiagnostics {
  static final Object _sinkZoneKey = Object();
  static final SparkDiagnosticSink _productionSink = _writeToDeveloperLog;

  static SparkDiagnosticSink get _activeSink =>
      Zone.current[_sinkZoneKey] as SparkDiagnosticSink? ?? _productionSink;

  static void reportUnexpected({
    required SparkDiagnosticOperation operation,
    required Object error,
    required StackTrace stackTrace,
    SparkDiagnosticSeverity severity = SparkDiagnosticSeverity.error,
  }) {
    _emit(
      _activeSink,
      SparkDiagnosticEvent(
        operation: operation,
        severity: severity,
        errorType: error.runtimeType.toString(),
        stackTrace: stackTrace,
      ),
    );
  }

  /// 在指定 sink 的 Zone 中运行代码，供测试和未来进程级接入使用。
  static R runWithSink<R>(SparkDiagnosticSink sink, R Function() body) {
    return runZoned(body, zoneValues: {_sinkZoneKey: sink});
  }

  /// 记录 Zone 未处理错误后继续向父 Zone 传播，保持原进程错误语义。
  static R? runGuarded<R>(R Function() body) {
    final sink = _activeSink;
    return runZonedGuarded(body, (error, stackTrace) {
      _emit(
        sink,
        SparkDiagnosticEvent(
          operation: SparkDiagnosticOperation.dartUnhandled,
          severity: SparkDiagnosticSeverity.error,
          errorType: error.runtimeType.toString(),
          stackTrace: stackTrace,
        ),
      );
      Error.throwWithStackTrace(error, stackTrace);
    }, zoneValues: {_sinkZoneKey: sink});
  }

  static void _emit(SparkDiagnosticSink sink, SparkDiagnosticEvent event) {
    try {
      sink(event);
    } on Object catch (sinkError, sinkStackTrace) {
      if (identical(sink, _productionSink)) {
        Error.throwWithStackTrace(sinkError, sinkStackTrace);
      }
      _productionSink(event);
    }
  }

  static void _writeToDeveloperLog(SparkDiagnosticEvent event) {
    developer.log(
      event.summary,
      name: 'spark.${event.operation.code}',
      level: event.severity.developerLogLevel,
      stackTrace: event.stackTrace,
    );
  }
}
