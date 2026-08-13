import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spark/src/core/diagnostics/diagnostics.dart';
import 'package:spark/src/features/chat/data/deepseek_chat_ai_service.dart';
import 'package:spark/src/features/papers/application/paper_translation_controller.dart';
import 'package:spark/src/features/papers/application/paper_translation_service.dart';
import 'package:spark/src/features/papers/data/deepseek_paper_translation_service.dart';
import 'package:spark/src/features/papers/data/demo_paper_repository.dart';
import 'package:spark/src/features/papers/data/in_memory_paper_translation_repository.dart';
import 'package:spark/src/features/papers/domain/paper.dart';

void main() {
  test('DeepSeek translation uses streaming with thinking disabled', () async {
    late http.Request captured;
    final aiClient = DeepSeekChatAiService(
      apiKey: 'test-key',
      model: 'deepseek-v4-flash',
      thinkingEnabled: false,
      client: MockClient((request) async {
        captured = request;
        return http.Response.bytes(
          utf8.encode(
            '${_event('这是')}${_event('中文翻译')}$_stopEvent',
          ),
          200,
          headers: {'content-type': 'text/event-stream; charset=utf-8'},
        );
      }),
    );
    final service = DeepSeekPaperTranslationService(client: aiClient);

    final result = await service.translateAbstract(demoPapers.first).join();

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['stream'], isTrue);
    expect(body['thinking'], {'type': 'disabled'});
    expect(body, isNot(contains('output_config')));
    expect(
      (body['messages'] as List).last['content'],
      contains(demoPapers.first.content.originalAbstractMarkdown),
    );
    expect(result, '这是中文翻译');
  });

  test('translation controller caches each paper translation locally',
      () async {
    final repository = InMemoryPaperTranslationRepository();
    final service = _FakeTranslationService();
    final generatedAt = DateTime.utc(2026, 8, 7, 10);
    final controller = PaperTranslationController(
      paper: demoPapers.first,
      service: service,
      repository: repository,
      clock: () => generatedAt,
    );

    await controller.initialize();
    await controller.ensureTranslated();
    expect(controller.markdown, '第一段中文翻译');
    expect(service.requests, 1);
    final stored = await repository.load(demoPapers.first.id);
    expect(stored?.markdown, '第一段中文翻译');
    expect(stored?.inputFingerprint,
        paperTranslationInputFingerprint(demoPapers.first));
    expect(stored?.promptVersion, paperTranslationPromptVersion);
    expect(stored?.generatedAt, generatedAt);

    final restoredService = _FakeTranslationService();
    final restored = PaperTranslationController(
      paper: demoPapers.first,
      service: restoredService,
      repository: repository,
    );
    await restored.initialize();
    await restored.ensureTranslated();

    expect(restored.markdown, '第一段中文翻译');
    expect(restoredService.requests, 0);
    controller.dispose();
    restored.dispose();
  });

  test('translation fingerprint changes with title or Abstract', () {
    final original = _paper();

    expect(
      paperTranslationInputFingerprint(_paper(title: 'Changed title')),
      isNot(paperTranslationInputFingerprint(original)),
    );
    expect(
      paperTranslationInputFingerprint(_paper(abstractText: 'Changed text')),
      isNot(paperTranslationInputFingerprint(original)),
    );
  });

  test('translation controller ignores stale cached records', () async {
    final repository = InMemoryPaperTranslationRepository();
    final paper = _paper();
    await repository.save(
      PaperTranslationRecord(
        paperId: paper.id,
        markdown: '过期翻译',
        inputFingerprint: 'stale',
        promptVersion: paperTranslationPromptVersion,
        generatedAt: DateTime.utc(2026, 8, 6),
      ),
    );
    final service = _FakeTranslationService();
    final controller = PaperTranslationController(
      paper: paper,
      service: service,
      repository: repository,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.ensureTranslated();

    expect(service.requests, 1);
    expect(controller.markdown, '第一段中文翻译');
  });

  test('translation controller ignores records from an older prompt', () async {
    final repository = InMemoryPaperTranslationRepository();
    final paper = _paper();
    await repository.save(
      PaperTranslationRecord(
        paperId: paper.id,
        markdown: '旧提示词翻译',
        inputFingerprint: paperTranslationInputFingerprint(paper),
        promptVersion: paperTranslationPromptVersion - 1,
        generatedAt: DateTime.utc(2026, 8, 6),
      ),
    );
    final controller = PaperTranslationController(
      paper: paper,
      service: _FakeTranslationService(),
      repository: repository,
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.hasTranslation, isFalse);
  });

  test('translation cache load failures report while retaining fallback',
      () async {
    final controller = PaperTranslationController(
      paper: _paper(),
      service: _FakeTranslationService(),
      repository: _ThrowingTranslationRepository(loadFailure: true),
    );
    addTearDown(controller.dispose);
    final events = <SparkDiagnosticEvent>[];

    await SparkDiagnostics.runWithSink(events.add, controller.initialize);

    expect(controller.markdown, isEmpty);
    expect(controller.error, '无法读取中文摘要缓存。');
    expect(
      events.map((event) => event.operation),
      [SparkDiagnosticOperation.paperTranslationLoad],
    );
  });

  test('translation generation and cache save use distinct operations',
      () async {
    final generationController = PaperTranslationController(
      paper: _paper(),
      service: _FailingTranslationService(),
    );
    final saveController = PaperTranslationController(
      paper: _paper(),
      service: _FakeTranslationService(),
      repository: _ThrowingTranslationRepository(saveFailure: true),
    );
    addTearDown(generationController.dispose);
    addTearDown(saveController.dispose);
    final events = <SparkDiagnosticEvent>[];

    await SparkDiagnostics.runWithSink(events.add, () async {
      await generationController.translate();
      await saveController.translate();
    });

    expect(generationController.error, '翻译服务失败');
    expect(saveController.markdown, '第一段中文翻译');
    expect(saveController.error, '翻译保存失败');
    expect(
      events.map((event) => event.operation),
      [
        SparkDiagnosticOperation.paperTranslationGenerate,
        SparkDiagnosticOperation.paperTranslationSave,
      ],
    );
  });

  test('translation cancellation does not emit a failure event', () async {
    final service = _CancellableTranslationService();
    final controller = PaperTranslationController(
      paper: _paper(),
      service: service,
    );
    addTearDown(controller.dispose);
    final events = <SparkDiagnosticEvent>[];

    await SparkDiagnostics.runWithSink(events.add, () async {
      final translation = controller.translate();
      await service.started.future;
      controller.cancel();
      await translation;
    });

    expect(controller.translating, isFalse);
    expect(controller.error, isNull);
    expect(events, isEmpty);
  });
}

Paper _paper({
  String title = 'Paper title',
  String abstractText = 'An Abstract about methods.',
}) {
  return Paper(
    id: 'paper-1',
    title: title,
    authors: const ['Author'],
    abstractText: abstractText,
    chineseAbstractMarkdown: '',
    readMinutes: 2,
  );
}

String _event(String content) {
  return 'data: ${jsonEncode({
        'type': 'content_block_delta',
        'delta': {'type': 'text_delta', 'text': content},
      })}\n\n';
}

const _stopEvent = 'data: {"type":"message_stop"}\n\n';

class _FakeTranslationService implements PaperTranslationService {
  int requests = 0;

  @override
  Stream<String> translateAbstract(Paper paper) async* {
    requests++;
    yield '第一段';
    yield '中文翻译';
  }

  @override
  void cancelActiveTranslation() {}
}

class _FailingTranslationService implements PaperTranslationService {
  @override
  Stream<String> translateAbstract(Paper paper) async* {
    throw const PaperTranslationException('翻译服务失败');
  }

  @override
  void cancelActiveTranslation() {}
}

class _CancellableTranslationService implements PaperTranslationService {
  final started = Completer<void>();
  final cancelled = Completer<void>();

  @override
  Stream<String> translateAbstract(Paper paper) async* {
    started.complete();
    await cancelled.future;
    throw const PaperTranslationException('已取消');
  }

  @override
  void cancelActiveTranslation() {
    if (!cancelled.isCompleted) cancelled.complete();
  }
}

class _ThrowingTranslationRepository implements PaperTranslationRepository {
  const _ThrowingTranslationRepository({
    this.loadFailure = false,
    this.saveFailure = false,
  });

  final bool loadFailure;
  final bool saveFailure;

  @override
  Future<void> clear(String paperId) async {}

  @override
  Future<PaperTranslationRecord?> load(String paperId) async {
    if (loadFailure) throw StateError('private-translation-cache');
    return null;
  }

  @override
  Future<void> save(PaperTranslationRecord record) async {
    if (saveFailure) {
      throw const PaperTranslationPersistenceException('翻译保存失败');
    }
  }
}
