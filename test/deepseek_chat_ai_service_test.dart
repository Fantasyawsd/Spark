import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spark/src/features/ai_settings/data/in_memory_deepseek_credential_repository.dart';
import 'package:spark/src/features/chat/chat.dart';
import 'package:spark/src/features/chat/data/deepseek_chat_ai_service.dart';
import 'package:spark/src/features/papers/application/paper_chat_context.dart';
import 'support/demo_paper_repository.dart';

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
    final service = DeepSeekChatAiService(
      apiKey: 'test-key',
      baseUrl: 'https://example.test/v1',
      model: 'deepseek-v4-flash',
      client: client,
    );

    final result = await service.answer(
      context: PaperChatContext.fromPaper(demoPapers.first),
      conversation: const [
        ChatMessage(fromUser: true, content: '解释核心方法'),
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
    expect(body['thinking'], {'type': 'enabled', 'budget_tokens': 2048});
    expect(body['output_config'], {'effort': 'high'});
    expect(body, isNot(contains('temperature')));
    expect(body['system'], contains(demoPapers.first.title));
    final messages = body['messages'] as List<dynamic>;
    expect(messages.single['content'], '解释核心方法');
    expect(result, '**回答**\n\n- 要点');
  });

  test('DeepSeek Anthropic stream separates reasoning and answer deltas',
      () async {
    final service = DeepSeekChatAiService(
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
        ChatMessage(fromUser: true, content: '解释方法'),
      ],
    ).toList();

    expect(chunks.map((chunk) => chunk.reasoningDelta).join(), '步骤一，步骤二');
    expect(chunks.map((chunk) => chunk.contentDelta).join(), '最终答案');
  });

  test('DeepSeek can disable reasoning per conversation', () async {
    late http.Request captured;
    final service = DeepSeekChatAiService(
      apiKey: 'test-key',
      client: MockClient((request) async {
        captured = request;
        return _sseResponse('${_event(content: '直接回答')}$_stopEvent');
      }),
    );
    service.setReasoningEffort(ChatReasoningEffort.none);

    await service.answer(
      context: PaperChatContext.fromPaper(demoPapers.first),
      conversation: const [
        ChatMessage(fromUser: true, content: '直接回答'),
      ],
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['thinking'], {'type': 'disabled'});
    expect(body, isNot(contains('output_config')));
  });

  test('DeepSeek service rejects missing API key before network access',
      () async {
    final service = DeepSeekChatAiService(
      apiKey: '',
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    await expectLater(
      service.answer(
        context: PaperChatContext.fromPaper(demoPapers.first),
        conversation: const [
          ChatMessage(fromUser: true, content: 'test'),
        ],
      ),
      throwsA(
        isA<ChatAiException>().having(
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
    final service = DeepSeekChatAiService(
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
        ChatMessage(fromUser: true, content: 'test'),
      ],
    );

    expect(captured.headers['x-api-key'], 'sk-replaced');
  });

  test('DeepSeek service maps authentication errors', () async {
    final service = DeepSeekChatAiService(
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
          ChatMessage(fromUser: true, content: 'test'),
        ],
      ),
      throwsA(
        isA<ChatAiException>().having(
          (error) => error.message,
          'message',
          contains('鉴权失败'),
        ),
      ),
    );
  });

  test('DeepSeek request times out while waiting for response headers',
      () async {
    final client = _StreamingTestClient(
      (_) => Completer<http.StreamedResponse>().future,
    );
    final service = DeepSeekChatAiService(
      apiKey: 'test-key',
      client: client,
      timeouts: const DeepSeekChatRequestTimeouts(
        header: Duration(milliseconds: 100),
        idle: Duration(milliseconds: 500),
        total: Duration(seconds: 2),
      ),
    );

    await expectLater(
      service.answer(
        context: PaperChatContext.fromPaper(demoPapers.first),
        conversation: const [
          ChatMessage(fromUser: true, content: 'header timeout'),
        ],
      ),
      throwsA(
        isA<ChatAiException>().having(
          (error) => error.message,
          'message',
          contains('超时'),
        ),
      ),
    );
    expect(client.closeCalls, 0);
  });

  test('DeepSeek request times out when the response stream becomes idle',
      () async {
    final response = StreamController<List<int>>();
    addTearDown(response.close);
    final client = _StreamingTestClient(
      (_) async => _streamedResponse(response.stream),
    );
    final service = DeepSeekChatAiService(
      apiKey: 'test-key',
      client: client,
      timeouts: const DeepSeekChatRequestTimeouts(
        header: Duration(milliseconds: 500),
        idle: Duration(milliseconds: 100),
        total: Duration(seconds: 2),
      ),
    );

    await expectLater(
      service.answer(
        context: PaperChatContext.fromPaper(demoPapers.first),
        conversation: const [
          ChatMessage(fromUser: true, content: 'idle timeout'),
        ],
      ),
      throwsA(
        isA<ChatAiException>().having(
          (error) => error.message,
          'message',
          contains('超时'),
        ),
      ),
    );
  });

  test('DeepSeek request has an absolute timeout despite stream activity',
      () async {
    final response = StreamController<List<int>>();
    final heartbeat = Timer.periodic(
      const Duration(milliseconds: 25),
      (_) => response.add(utf8.encode(': keepalive\n\n')),
    );
    addTearDown(() async {
      heartbeat.cancel();
      await response.close();
    });
    final service = DeepSeekChatAiService(
      apiKey: 'test-key',
      client: _StreamingTestClient(
        (_) async => _streamedResponse(response.stream),
      ),
      timeouts: const DeepSeekChatRequestTimeouts(
        header: Duration(milliseconds: 500),
        idle: Duration(milliseconds: 500),
        total: Duration(milliseconds: 250),
      ),
    );

    await expectLater(
      service.answer(
        context: PaperChatContext.fromPaper(demoPapers.first),
        conversation: const [
          ChatMessage(fromUser: true, content: 'total timeout'),
        ],
      ),
      throwsA(
        isA<ChatAiException>().having(
          (error) => error.message,
          'message',
          contains('超时'),
        ),
      ),
    );
  });

  test('DeepSeek bounds a non-success response body stream', () async {
    final response = StreamController<List<int>>();
    addTearDown(response.close);
    final service = DeepSeekChatAiService(
      apiKey: 'test-key',
      client: _StreamingTestClient(
        (_) async => _streamedResponse(response.stream, statusCode: 500),
      ),
      timeouts: const DeepSeekChatRequestTimeouts(
        header: Duration(milliseconds: 500),
        idle: Duration(milliseconds: 100),
        total: Duration(seconds: 2),
      ),
    );

    await expectLater(
      service.answer(
        context: PaperChatContext.fromPaper(demoPapers.first),
        conversation: const [
          ChatMessage(fromUser: true, content: 'error body timeout'),
        ],
      ),
      throwsA(
        isA<ChatAiException>().having(
          (error) => error.message,
          'message',
          contains('超时'),
        ),
      ),
    );
  });

  test('cancelling one DeepSeek request does not affect another request',
      () async {
    final streams = <String, StreamController<List<int>>>{};
    final requestsReady = Completer<void>();
    final client = _StreamingTestClient((request) async {
      final body =
          jsonDecode((request as http.Request).body) as Map<String, dynamic>;
      final messages = body['messages'] as List<dynamic>;
      final prompt =
          (messages.last as Map<String, dynamic>)['content'] as String;
      streams[prompt] = StreamController<List<int>>();
      if (streams.length == 2 && !requestsReady.isCompleted) {
        requestsReady.complete();
      }
      return _streamedResponse(streams[prompt]!.stream);
    });
    addTearDown(() async {
      for (final stream in streams.values) {
        if (!stream.isClosed) await stream.close();
      }
    });
    final service = DeepSeekChatAiService(
      apiKey: 'test-key',
      client: client,
      timeouts: const DeepSeekChatRequestTimeouts(
        header: Duration(seconds: 1),
        idle: Duration(seconds: 1),
        total: Duration(seconds: 2),
      ),
    );
    final cancellationA = ChatRequestCancellation();
    final cancellationB = ChatRequestCancellation();

    final requestA = service
        .answerStream(
          context: PaperChatContext.fromPaper(demoPapers.first),
          conversation: const [
            ChatMessage(fromUser: true, content: 'request-a'),
          ],
          cancellation: cancellationA,
        )
        .toList();
    final requestB = service
        .answerStream(
          context: PaperChatContext.fromPaper(demoPapers.first),
          conversation: const [
            ChatMessage(fromUser: true, content: 'request-b'),
          ],
          cancellation: cancellationB,
        )
        .toList();
    await requestsReady.future;
    final cancelledExpectation = expectLater(
      requestA,
      throwsA(isA<ChatAiCancelledException>()),
    );

    cancellationA.cancel();
    await cancelledExpectation;
    streams['request-b']!
      ..add(utf8.encode('${_event(content: 'B 正常完成')}$_stopEvent'))
      ..close();

    final chunksB = await requestB;
    expect(chunksB.map((chunk) => chunk.contentDelta).join(), 'B 正常完成');
    expect(cancellationB.isCancelled, isFalse);
    expect(client.closeCalls, 0);
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

http.StreamedResponse _streamedResponse(
  Stream<List<int>> stream, {
  int statusCode = 200,
}) =>
    http.StreamedResponse(
      stream,
      statusCode,
      headers: {'content-type': 'text/event-stream; charset=utf-8'},
    );

class _StreamingTestClient extends http.BaseClient {
  _StreamingTestClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
      _handler;
  int closeCalls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _handler(request);

  @override
  void close() {
    closeCalls++;
  }
}
