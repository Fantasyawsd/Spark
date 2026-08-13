import 'package:flutter/foundation.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../domain/paper.dart';
import '../domain/paper_keyword_repository.dart';
import '../domain/paper_keyword_cache.dart';
import '../../chat/chat.dart';
import 'paper_keyword_service.dart';

class PaperKeywordController extends ChangeNotifier {
  PaperKeywordController({
    required this.paper,
    required ChatAiService service,
    PaperKeywordRepository? repository,
  })  : _service = service,
        _generator = PaperKeywordGenerator(service),
        _repository = repository;

  final Paper paper;
  final ChatAiService _service;
  final PaperKeywordGenerator _generator;
  final PaperKeywordRepository? _repository;

  List<String> _keywords = const [];
  String? _error;
  bool _loadingCache = false;
  bool _cacheInitialized = false;
  bool _cacheLoadFailed = false;
  bool _generating = false;
  bool _disposed = false;
  int _requestVersion = 0;
  Future<void>? _cacheInitialization;

  List<String> get keywords => _keywords;
  String? get error => _error;
  bool get loadingCache => _loadingCache;
  bool get cacheLoadFailed => _cacheLoadFailed;
  bool get generating => _generating;
  bool get hasKeywords => _keywords.isNotEmpty;

  Future<void> initialize() {
    final repository = _repository;
    if (_disposed || repository == null || hasKeywords) return Future.value();
    final initialization = _cacheInitialization;
    if (initialization != null) return initialization;
    if (_cacheInitialized) return Future.value();
    _cacheInitialized = true;
    return _cacheInitialization = _loadCache(repository);
  }

  Future<void> _loadCache(PaperKeywordRepository repository) async {
    _loadingCache = true;
    _notify();
    try {
      final record = await repository.load(paper.id);
      if (record != null && isPaperKeywordCacheFresh(record, paper)) {
        _keywords = record.keywords;
      }
    } on PaperKeywordPersistenceException catch (error, stackTrace) {
      _reportPersistenceFailure(
        SparkDiagnosticOperation.paperKeywordsLoad,
        error,
        stackTrace,
      );
      _cacheLoadFailed = true;
      _error = error.message;
    } on Object catch (error, stackTrace) {
      _reportPersistenceFailure(
        SparkDiagnosticOperation.paperKeywordsLoad,
        error,
        stackTrace,
      );
      _cacheLoadFailed = true;
      _error = '无法读取关键词缓存。';
    } finally {
      if (!_disposed) {
        _loadingCache = false;
        _notify();
      }
    }
  }

  Future<void> generate({bool force = false}) async {
    if (_generating || (!force && hasKeywords)) return;
    final previous = _keywords;
    final requestVersion = ++_requestVersion;
    _error = null;
    _generating = true;
    _notify();
    try {
      final keywords = await _generator.generate(paper);
      if (_disposed || requestVersion != _requestVersion) return;
      _keywords = keywords;
      _generating = false;
      _notify();
      await _save();
    } on PaperKeywordGenerationException catch (error, stackTrace) {
      _reportGenerationFailure(requestVersion, error, stackTrace);
      _handleError(requestVersion, error.message, previous);
    } on ChatAiCancelledException {
      _handleError(requestVersion, null, previous);
    } on ChatAiException catch (error, stackTrace) {
      _reportGenerationFailure(requestVersion, error, stackTrace);
      _handleError(requestVersion, '关键词生成失败，请稍后重试。', previous);
    } on Exception catch (error, stackTrace) {
      _reportGenerationFailure(requestVersion, error, stackTrace);
      _handleError(requestVersion, '关键词生成失败，请稍后重试。', previous);
    }
  }

  void cancel() {
    if (!_generating) return;
    _requestVersion++;
    if (_service is CancellableChatAiService) {
      (_service as CancellableChatAiService).cancelActiveRequest();
    }
    _generating = false;
    _notify();
  }

  void _handleError(
    int requestVersion,
    String? message,
    List<String> previous,
  ) {
    if (_disposed || requestVersion != _requestVersion) return;
    _keywords = previous;
    _error = message;
    _generating = false;
    _notify();
  }

  Future<void> _save() async {
    final repository = _repository;
    if (repository == null) return;
    try {
      await repository.save(
        PaperKeywordCache(
          paperId: paper.id,
          keywords: _keywords,
          inputFingerprint: paperKeywordInputFingerprint(paper),
          promptVersion: paperKeywordPromptVersion,
          generatedAt: DateTime.now().toUtc(),
        ),
      );
    } on PaperKeywordPersistenceException catch (error, stackTrace) {
      _reportPersistenceFailure(
        SparkDiagnosticOperation.paperKeywordsSave,
        error,
        stackTrace,
      );
      if (!_disposed) {
        _error = error.message;
        _notify();
      }
    }
  }

  void _reportGenerationFailure(
    int requestVersion,
    Object error,
    StackTrace stackTrace,
  ) {
    if (_disposed || requestVersion != _requestVersion) return;
    SparkDiagnostics.reportUnexpected(
      operation: SparkDiagnosticOperation.paperKeywordsGenerate,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void _reportPersistenceFailure(
    SparkDiagnosticOperation operation,
    Object error,
    StackTrace stackTrace,
  ) {
    SparkDiagnostics.reportUnexpected(
      operation: operation,
      error: error,
      stackTrace: stackTrace,
      severity: SparkDiagnosticSeverity.warning,
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
