import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/paper.dart';
import 'paper_translation_service.dart';

class PaperTranslationController extends ChangeNotifier {
  PaperTranslationController({
    required this.paper,
    required PaperTranslationService service,
    PaperTranslationRepository? repository,
    DateTime Function()? clock,
  })  : _service = service,
        _repository = repository,
        _clock = clock ?? DateTime.now;

  final Paper paper;
  final PaperTranslationService _service;
  final PaperTranslationRepository? _repository;
  final DateTime Function() _clock;

  String _markdown = '';
  String? _error;
  bool _loadingCache = false;
  bool _cacheInitialized = false;
  bool _translating = false;
  bool _disposed = false;
  int _requestVersion = 0;
  Timer? _notifyTimer;

  String get markdown => _markdown;
  String? get error => _error;
  bool get loadingCache => _loadingCache;
  bool get translating => _translating;
  bool get hasTranslation => _markdown.trim().isNotEmpty;

  Future<void> initialize() async {
    final repository = _repository;
    if (_disposed ||
        repository == null ||
        _cacheInitialized ||
        _loadingCache ||
        hasTranslation) {
      return;
    }
    _cacheInitialized = true;
    _loadingCache = true;
    _notify();
    try {
      final record = await repository.load(paper.id);
      if (record != null && isPaperTranslationRecordFresh(record, paper)) {
        _markdown = record.markdown;
      }
    } on PaperTranslationPersistenceException catch (error) {
      _error = error.message;
    } on Object {
      _error = '无法读取中文摘要缓存。';
    } finally {
      if (!_disposed) {
        _loadingCache = false;
        _notify();
      }
    }
  }

  Future<void> ensureTranslated() async {
    if (_loadingCache) {
      while (_loadingCache && !_disposed) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }
    if (!hasTranslation && !_translating) await translate();
  }

  Future<void> translate({bool force = false}) async {
    if (_translating || (!force && hasTranslation)) return;
    final previous = _markdown;
    final requestVersion = ++_requestVersion;
    _markdown = '';
    _error = null;
    _translating = true;
    _notify();
    try {
      await for (final delta in _service.translateAbstract(paper)) {
        if (_disposed || requestVersion != _requestVersion) return;
        _markdown += delta;
        _scheduleNotify();
      }
      if (_disposed || requestVersion != _requestVersion) return;
      if (!hasTranslation) {
        throw const PaperTranslationException('DeepSeek 没有返回翻译内容。');
      }
      _translating = false;
      _notifyTimer?.cancel();
      _notify();
      await _save();
    } on PaperTranslationException catch (error) {
      _handleError(requestVersion, error.message, previous);
    } on Exception {
      _handleError(requestVersion, '中文翻译失败，请稍后重试。', previous);
    }
  }

  void cancel() {
    if (!_translating) return;
    _requestVersion++;
    _service.cancelActiveTranslation();
    _translating = false;
    _notifyTimer?.cancel();
    _notify();
  }

  void _handleError(int requestVersion, String message, String previous) {
    if (_disposed || requestVersion != _requestVersion) return;
    _markdown = previous;
    _error = message;
    _translating = false;
    _notifyTimer?.cancel();
    _notify();
  }

  Future<void> _save() async {
    final repository = _repository;
    if (repository == null) return;
    try {
      await repository.save(
        PaperTranslationRecord(
          paperId: paper.id,
          markdown: _markdown,
          inputFingerprint: paperTranslationInputFingerprint(paper),
          promptVersion: paperTranslationPromptVersion,
          generatedAt: _clock().toUtc(),
        ),
      );
    } on PaperTranslationPersistenceException catch (error) {
      if (!_disposed) {
        _error = error.message;
        _notify();
      }
    }
  }

  void _scheduleNotify() {
    if (_notifyTimer?.isActive ?? false) return;
    _notifyTimer = Timer(const Duration(milliseconds: 32), _notify);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    _notifyTimer?.cancel();
    _service.cancelActiveTranslation();
    super.dispose();
  }
}
