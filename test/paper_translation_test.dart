import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
