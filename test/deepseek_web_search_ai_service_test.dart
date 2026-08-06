import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spark/spark.dart';
import 'package:spark/src/features/papers/application/paper_chat_context.dart';

void main() {
  test('DeepSeek web search uses native server tool and parses sources',
      () async {
    late http.Request captured;
    final service = DeepSeekWebSearchAiService(
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
        PaperAiMessage(fromUser: true, content: '查找后续研究'),
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
}

String _event(Map<String, Object> payload) =>
    'data: ${jsonEncode(payload)}\n\n';
