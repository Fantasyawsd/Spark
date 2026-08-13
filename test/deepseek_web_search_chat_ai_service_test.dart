import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spark/src/features/chat/chat.dart';
import 'package:spark/src/features/chat/data/deepseek_web_search_chat_ai_service.dart';
import 'package:spark/src/features/papers/application/paper_chat_context.dart';
import 'support/demo_paper_repository.dart';

void main() {
  test('DeepSeek web search uses native server tool and parses sources',
      () async {
    late http.Request captured;
    final service = DeepSeekWebSearchChatAiService(
      apiKey: 'test-key',
      baseUrl: 'https://example.test',
      model: 'deepseek-v4-flash',
      client: MockClient((request) async {
        captured = request;
        return http.Response.bytes(
          utf8.encode(
            '${_event({
                  'type': 'content_block_start',
                  'content_block': {
                    'type': 'server_tool_use',
                    'name': 'web_search',
                  },
                })}'
            '${_event({
                  'type': 'content_block_start',
                  'content_block': {
                    'type': 'web_search_tool_result',
                    'content': [
                      {
                        'type': 'web_search_result',
                        'title': 'DeepSeek API Docs',
                        'url': 'https://api-docs.deepseek.com/',
                      },
                    ],
                  },
                })}'
            '${_event({
                  'type': 'content_block_delta',
                  'delta': {'type': 'thinking_delta', 'thinking': '核对来源'},
                })}'
            '${_event({
                  'type': 'content_block_delta',
                  'delta': {'type': 'text_delta', 'text': '联网回答'},
                })}'
            '${_event({'type': 'message_stop'})}',
          ),
          200,
          headers: {'content-type': 'text/event-stream; charset=utf-8'},
        );
      }),
    );

    final chunks = await service.answerStream(
      context: PaperChatContext.fromPaper(demoPapers.first),
      conversation: const [
        ChatMessage(fromUser: true, content: '查找后续研究'),
      ],
    ).toList();

    expect(
        captured.url.toString(), 'https://example.test/anthropic/v1/messages');
    expect(captured.headers['x-api-key'], 'test-key');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['stream'], isTrue);
    expect(body['output_config'], {'effort': 'high'});
    expect((body['tools'] as List).first['type'], 'web_search_20250305');
    expect(chunks.any((chunk) => chunk.searchStarted), isTrue);
    expect(chunks.map((chunk) => chunk.reasoningDelta).join(), '核对来源');
    expect(chunks.map((chunk) => chunk.contentDelta).join(), '联网回答');
    expect(
      chunks.expand((chunk) => chunk.sources).single.url,
      'https://api-docs.deepseek.com/',
    );
  });

  test('DeepSeek web search bounds an idle response stream', () async {
    final response = StreamController<List<int>>();
    addTearDown(response.close);
    final service = DeepSeekWebSearchChatAiService(
      apiKey: 'test-key',
      client: _WebStreamingTestClient(
        (_) async => http.StreamedResponse(response.stream, 200),
      ),
      timeouts: const DeepSeekChatRequestTimeouts(
        header: Duration(milliseconds: 500),
        idle: Duration(milliseconds: 100),
        total: Duration(seconds: 2),
      ),
    );

    await expectLater(
      service.answerStream(
        context: PaperChatContext.fromPaper(demoPapers.first),
        conversation: const [
          ChatMessage(fromUser: true, content: '查找资料'),
        ],
      ).toList(),
      throwsA(
        isA<ChatAiException>().having(
          (error) => error.message,
          'message',
          contains('超时'),
        ),
      ),
    );
  });
}

String _event(Map<String, Object> payload) =>
    'data: ${jsonEncode(payload)}\n\n';

class _WebStreamingTestClient extends http.BaseClient {
  _WebStreamingTestClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
      _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _handler(request);
}
