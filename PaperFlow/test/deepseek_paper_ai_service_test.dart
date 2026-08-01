import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paperflow/paperflow.dart';
import 'package:paperflow/src/features/papers/application/paper_chat_context.dart';

void main() {
  test('DeepSeek Anthropic service sends paper context and conversation',
      () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return _sseResponse(
        '${_event(reasoning: '先分析方法。')}'
        '${_event(content: '**回答**')}'
        '${_event(content: '\n\n- 要点')}'
        '$_stopEvent',
      );
    });
    final service = DeepSeekPaperAiService(
      apiKey: 'test-key',
      baseUrl: 'https://example.test/v1',
      model: 'deepseek-v4-flash',
      client: client,
    );

    final result = await service.answer(
      context: PaperChatContext.fromPaper(demoPapers.first),
      conversation: const [
        PaperAiMessage(fromUser: true, content: '解释核心方法'),
      ],
    );

    expect(
      captured.url.toString(),
      'https://example.test/v1/anthropic/v1/messages',
    );
    expect(captured.headers['x-api-key'], 'test-key');
    expect(captured.headers['anthropic-version'], '2023-06-01');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['model'], 'deepseek-v4-flash');
    expect(body['stream'], isTrue);
    expect(body['thinking'], {'type': 'enabled', 'budget_tokens': 1024});
    expect(body['output_config'], {'effort': 'medium'});
    expect(body, isNot(contains('temperature')));
    expect(body['system'], contains(demoPapers.first.title));
    final messages = body['messages'] as List<dynamic>;
    expect(messages.single['content'], '解释核心方法');
    expect(result, '**回答**\n\n- 要点');
  });

  test('DeepSeek Anthropic stream separates reasoning and answer deltas',
      () async {
    final service = DeepSeekPaperAiService(
      apiKey: 'test-key',
      client: MockClient(
        (_) async => _sseResponse(
          '${_event(reasoning: '步骤一')}'
          '${_event(reasoning: '，步骤二')}'
          '${_event(content: '最终答案')}'
          '$_stopEvent',
        ),
      ),
    );

    final chunks = await service.answerStream(
      context: PaperChatContext.fromPaper(demoPapers.first),
      conversation: const [
        PaperAiMessage(fromUser: true, content: '解释方法'),
      ],
    ).toList();

    expect(chunks.map((chunk) => chunk.reasoningDelta).join(), '步骤一，步骤二');
    expect(chunks.map((chunk) => chunk.contentDelta).join(), '最终答案');
  });

  test('DeepSeek can disable reasoning per conversation', () async {
    late http.Request captured;
    final service = DeepSeekPaperAiService(
      apiKey: 'test-key',
      client: MockClient((request) async {
        captured = request;
        return _sseResponse('${_event(content: '直接回答')}$_stopEvent');
      }),
    );
    service.setReasoningEffort(PaperAiReasoningEffort.none);

    await service.answer(
      context: PaperChatContext.fromPaper(demoPapers.first),
      conversation: const [
        PaperAiMessage(fromUser: true, content: '直接回答'),
      ],
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['thinking'], {'type': 'disabled'});
    expect(body, isNot(contains('output_config')));
  });

  test('DeepSeek service rejects missing API key before network access',
      () async {
    final service = DeepSeekPaperAiService(
      apiKey: '',
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    await expectLater(
      service.answer(
        context: PaperChatContext.fromPaper(demoPapers.first),
        conversation: const [
          PaperAiMessage(fromUser: true, content: 'test'),
        ],
      ),
      throwsA(
        isA<PaperAiException>().having(
          (error) => error.message,
          'message',
          contains('我的'),
        ),
      ),
    );
  });

  test('reads the latest API key from the credential repository', () async {
    late http.Request captured;
    final credentials = InMemoryDeepSeekCredentialRepository('sk-first');
    final service = DeepSeekPaperAiService(
      apiKey: '',
      credentialRepository: credentials,
      client: MockClient((request) async {
        captured = request;
        return _sseResponse('${_event(content: 'ok')}$_stopEvent');
      }),
    );

    await credentials.saveApiKey('sk-replaced');
    await service.answer(
      context: PaperChatContext.fromPaper(demoPapers.first),
      conversation: const [
        PaperAiMessage(fromUser: true, content: 'test'),
      ],
    );

    expect(captured.headers['x-api-key'], 'sk-replaced');
  });

  test('DeepSeek service maps authentication errors', () async {
    final service = DeepSeekPaperAiService(
      apiKey: 'invalid',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {'message': 'invalid key'},
          }),
          401,
        ),
      ),
    );

    await expectLater(
      service.answer(
        context: PaperChatContext.fromPaper(demoPapers.first),
        conversation: const [
          PaperAiMessage(fromUser: true, content: 'test'),
        ],
      ),
      throwsA(
        isA<PaperAiException>().having(
          (error) => error.message,
          'message',
          contains('鉴权失败'),
        ),
      ),
    );
  });
}

String _event({String? reasoning, String? content}) {
  final delta = reasoning != null
      ? {'type': 'thinking_delta', 'thinking': reasoning}
      : {'type': 'text_delta', 'text': content ?? ''};
  return 'data: ${jsonEncode({
        'type': 'content_block_delta',
        'delta': delta,
      })}\n\n';
}

const _stopEvent = 'data: {"type":"message_stop"}\n\n';

http.Response _sseResponse(String body) => http.Response.bytes(
      utf8.encode(body),
      200,
      headers: {
        'content-type': 'text/event-stream; charset=utf-8',
      },
    );
