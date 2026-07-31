import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paperflow/paperflow.dart';

void main() {
  test('DeepSeek translation uses streaming with thinking disabled', () async {
    late http.Request captured;
    final aiClient = DeepSeekPaperAiService(
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
      contains(demoPapers.first.abstractText),
    );
    expect(result, '这是中文翻译');
  });

  test('translation controller caches each paper translation locally',
      () async {
    final repository = InMemoryPaperTranslationRepository();
    final service = _FakeTranslationService();
    final controller = PaperTranslationController(
      paper: demoPapers.first,
      service: service,
      repository: repository,
    );

    await controller.initialize();
    await controller.ensureTranslated();
    expect(controller.markdown, '第一段中文翻译');
    expect(service.requests, 1);

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
  Stream<String> translateAbstract(PaperRecord paper) async* {
    requests++;
    yield '第一段';
    yield '中文翻译';
  }

  @override
  void cancelActiveTranslation() {}
}
