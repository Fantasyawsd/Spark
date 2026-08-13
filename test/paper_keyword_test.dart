import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/core/diagnostics/diagnostics.dart';
import 'package:spark/src/features/chat/chat.dart';
import 'package:spark/src/features/papers/application/paper_keyword_controller.dart';
import 'package:spark/src/features/papers/application/paper_keyword_service.dart';
import 'package:spark/src/features/papers/data/in_memory_paper_keyword_repository.dart';
import 'package:spark/src/features/papers/domain/paper.dart';
import 'package:spark/src/features/papers/domain/paper_keyword_cache.dart';
import 'package:spark/src/features/papers/domain/paper_keyword_repository.dart';

void main() {
  group('PaperKeywordParser', () {
    test('parses fenced JSON and removes duplicates', () {
      final keywords = PaperKeywordParser.parse(
        '```json\n["LLM", "llm", "RAG", "Agents", "Evaluation", "Safety"]\n```',
      );

      expect(keywords, ['LLM', 'RAG', 'Agents', 'Evaluation', 'Safety']);
    });

    test('rejects keyword counts outside 5 to 12', () {
      expect(
        () => PaperKeywordParser.parse('["a", "b", "c", "d"]'),
        throwsA(isA<PaperKeywordGenerationException>()),
      );
    });
  });

  test('fingerprint changes with title or Abstract', () {
    final first = _paper(title: 'First');
    final second = _paper(title: 'Second');

    expect(
      paperKeywordInputFingerprint(first),
      isNot(paperKeywordInputFingerprint(second)),
    );
  });

  test('controller only restores a fresh generated record', () async {
    final repository = InMemoryPaperKeywordRepository();
    final paper = _paper();
    await repository.save(
      PaperKeywordCache(
        paperId: paper.id,
        keywords: const ['a', 'b', 'c', 'd', 'e'],
        inputFingerprint: 'stale',
        promptVersion: paperKeywordPromptVersion,
        generatedAt: DateTime.utc(2026, 8, 6),
      ),
    );
    final controller = PaperKeywordController(
      paper: paper,
      service: _FakeAiService('[]'),
      repository: repository,
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.keywords, isEmpty);
  });

  test('controller generates and persists normalized keywords', () async {
    final repository = InMemoryPaperKeywordRepository();
    final paper = _paper();
    final controller = PaperKeywordController(
      paper: paper,
      service: _FakeAiService('["A", "B", "C", "D", "E"]'),
      repository: repository,
    );
    addTearDown(controller.dispose);

    await controller.generate();

    expect(controller.keywords, ['A', 'B', 'C', 'D', 'E']);
    final stored = await repository.load(paper.id);
    expect(stored, isNotNull);
    expect(isPaperKeywordCacheFresh(stored!, paper), isTrue);
  });

  test(
    'keyword cache load failures report while retaining empty fallback',
    () async {
      final controller = PaperKeywordController(
        paper: _paper(),
        service: const _FakeAiService('[]'),
        repository: _ThrowingKeywordRepository(loadFailure: true),
      );
      addTearDown(controller.dispose);
      final events = <SparkDiagnosticEvent>[];

      await SparkDiagnostics.runWithSink(events.add, controller.initialize);

      expect(controller.keywords, isEmpty);
      expect(controller.error, '无法读取关键词缓存。');
      expect(events.map((event) => event.operation), [
        SparkDiagnosticOperation.paperKeywordsLoad,
      ]);
    },
  );

  test('concurrent cache initialization shares one repository load', () async {
    final repository = _PendingKeywordRepository();
    final controller = PaperKeywordController(
      paper: _paper(),
      service: const _FakeAiService('[]'),
      repository: repository,
    );
    addTearDown(controller.dispose);

    final first = controller.initialize();
    final second = controller.initialize();

    expect(repository.loadCalls, 1);
    repository.complete(null);
    await Future.wait([first, second]);
    expect(repository.loadCalls, 1);
  });

  test('keyword generation and cache save use distinct operations', () async {
    final generationController = PaperKeywordController(
      paper: _paper(),
      service: const _FakeAiService('[]'),
    );
    final saveController = PaperKeywordController(
      paper: _paper(),
      service: const _FakeAiService('["A", "B", "C", "D", "E"]'),
      repository: _ThrowingKeywordRepository(saveFailure: true),
    );
    addTearDown(generationController.dispose);
    addTearDown(saveController.dispose);
    final events = <SparkDiagnosticEvent>[];

    await SparkDiagnostics.runWithSink(events.add, () async {
      await generationController.generate();
      await saveController.generate();
    });

    expect(generationController.error, '关键词数量应为 5 至 12 个，请重试。');
    expect(saveController.keywords, ['A', 'B', 'C', 'D', 'E']);
    expect(saveController.error, '关键词保存失败');
    expect(events.map((event) => event.operation), [
      SparkDiagnosticOperation.paperKeywordsGenerate,
      SparkDiagnosticOperation.paperKeywordsSave,
    ]);
  });

  test('keyword cancellation remains expected control flow', () async {
    final controller = PaperKeywordController(
      paper: _paper(),
      service: const _ThrowingAiService(ChatAiCancelledException()),
    );
    addTearDown(controller.dispose);
    final events = <SparkDiagnosticEvent>[];

    await SparkDiagnostics.runWithSink(events.add, controller.generate);

    expect(controller.error, isNull);
    expect(events, isEmpty);
  });
}

Paper _paper({String title = 'Paper title'}) => Paper(
      id: 'paper-1',
      title: title,
      authors: const ['Author'],
      abstractText: 'An Abstract about methods and evaluation.',
      chineseAbstractMarkdown: '',
      readMinutes: 3,
    );

class _FakeAiService implements ChatAiService {
  const _FakeAiService(this.response);

  final String response;

  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async {
    return response;
  }
}

class _ThrowingAiService implements ChatAiService {
  const _ThrowingAiService(this.error);

  final Object error;

  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async {
    throw error;
  }
}

class _ThrowingKeywordRepository implements PaperKeywordRepository {
  const _ThrowingKeywordRepository({
    this.loadFailure = false,
    this.saveFailure = false,
  });

  final bool loadFailure;
  final bool saveFailure;

  @override
  Future<void> clear(String paperId) async {}

  @override
  Future<PaperKeywordCache?> load(String paperId) async {
    if (loadFailure) throw StateError('private-keyword-cache');
    return null;
  }

  @override
  Future<void> save(PaperKeywordCache cache) async {
    if (saveFailure) {
      throw const PaperKeywordPersistenceException('关键词保存失败');
    }
  }
}

class _PendingKeywordRepository implements PaperKeywordRepository {
  final Completer<PaperKeywordCache?> _loadCompleter = Completer();
  int loadCalls = 0;

  void complete(PaperKeywordCache? cache) => _loadCompleter.complete(cache);

  @override
  Future<void> clear(String paperId) async {}

  @override
  Future<PaperKeywordCache?> load(String paperId) {
    loadCalls++;
    return _loadCompleter.future;
  }

  @override
  Future<void> save(PaperKeywordCache cache) async {}
}
