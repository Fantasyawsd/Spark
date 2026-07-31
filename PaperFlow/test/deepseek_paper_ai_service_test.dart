import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paperflow/paperflow.dart';

void main() {
  test('DeepSeek service sends paper context and conversation', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {'content': '**回答**\n\n- 要点'},
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = DeepSeekPaperAiService(
      apiKey: 'test-key',
      baseUrl: 'https://example.test/v1',
      model: 'deepseek-chat',
      client: client,
    );

    final result = await service.answer(
      paper: demoPapers.first,
      conversation: const [
        PaperAiMessage(fromUser: true, content: '解释核心方法'),
      ],
    );

    expect(captured.url.toString(), 'https://example.test/v1/chat/completions');
    expect(captured.headers['Authorization'], 'Bearer test-key');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['model'], 'deepseek-chat');
    final messages = body['messages'] as List<dynamic>;
    expect(messages.first['content'], contains(demoPapers.first.title));
    expect(messages.last['content'], '解释核心方法');
    expect(result, '**回答**\n\n- 要点');
  });

  test('DeepSeek service rejects missing API key before network access',
      () async {
    final service = DeepSeekPaperAiService(
      apiKey: '',
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    await expectLater(
      service.answer(
        paper: demoPapers.first,
        conversation: const [
          PaperAiMessage(fromUser: true, content: 'test'),
        ],
      ),
      throwsA(
        isA<PaperAiException>().having(
          (error) => error.message,
          'message',
          contains('DEEPSEEK_API_KEY'),
        ),
      ),
    );
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
        paper: demoPapers.first,
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
