import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../application/paper_ai_prompt_builder.dart';
import '../application/paper_ai_service.dart';
import '../domain/paper.dart';

class DeepSeekWebSearchAiService
    implements
        PaperAiService,
        StreamingPaperAiService,
        CancellablePaperAiService,
        ConfigurablePaperAiService {
  DeepSeekWebSearchAiService({
    this.apiKey = const String.fromEnvironment('DEEPSEEK_API_KEY'),
    this.baseUrl = const String.fromEnvironment(
      'DEEPSEEK_BASE_URL',
      defaultValue: 'https://api.deepseek.com',
    ),
    this.model = const String.fromEnvironment(
      'DEEPSEEK_MODEL',
      defaultValue: 'deepseek-v4-flash',
    ),
    String reasoningEffort = const String.fromEnvironment(
      'DEEPSEEK_REASONING_EFFORT',
      defaultValue: 'medium',
    ),
    this.maxSearches = 3,
    this.systemPromptBuilder,
    http.Client? client,
  })  : _reasoningEffort = PaperAiReasoningEffort.fromApiValue(reasoningEffort),
        _injectedClient = client;

  final String apiKey;
  final String baseUrl;
  final String model;
  final int maxSearches;
  final String Function(PaperRecord paper)? systemPromptBuilder;
  final http.Client? _injectedClient;
  PaperAiReasoningEffort _reasoningEffort;

  String get reasoningEffort => _reasoningEffort.apiValue;

  @override
  void setReasoningEffort(PaperAiReasoningEffort effort) {
    _reasoningEffort = effort;
  }

  http.Client? _activeClient;
  int _requestSerial = 0;
  int? _cancelledRequest;

  @override
  Future<String> answer({
    required PaperRecord paper,
    required List<PaperAiMessage> conversation,
  }) async {
    final content = StringBuffer();
    await for (final chunk in answerStream(
      paper: paper,
      conversation: conversation,
    )) {
      content.write(chunk.contentDelta);
    }
    if (content.toString().trim().isEmpty) {
      throw const PaperAiException('DeepSeek 联网搜索没有返回回答。');
    }
    return content.toString().trim();
  }

  @override
  Stream<PaperAiStreamChunk> answerStream({
    required PaperRecord paper,
    required List<PaperAiMessage> conversation,
  }) async* {
    _validateConfiguration();
    final requestId = ++_requestSerial;
    final client = _injectedClient ?? http.Client();
    _activeClient = client;
    try {
      final request = http.Request('POST', _endpoint())
        ..headers.addAll({
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
        })
        ..body = jsonEncode(_requestBody(paper, conversation));
      final response =
          await client.send(request).timeout(const Duration(seconds: 60));
      _throwIfCancelled(requestId);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        throw PaperAiException(_apiError(response.statusCode, body));
      }

      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        _throwIfCancelled(requestId);
        if (!line.startsWith('data:')) continue;
        final data = line.substring(5).trim();
        if (data.isEmpty) continue;
        final payload = _decodePayload(data);
        if (payload['type'] == 'error') {
          throw PaperAiException(_eventError(payload));
        }
        final chunk = _streamChunk(payload);
        if (!chunk.isEmpty) yield chunk;
      }
    } on PaperAiCancelledException {
      rethrow;
    } on PaperAiException {
      rethrow;
    } on FormatException {
      throw const PaperAiException('DeepSeek 联网搜索返回了无法解析的数据。');
    } on TimeoutException {
      throw const PaperAiException('DeepSeek 联网搜索响应超时，请稍后重试。');
    } on Exception {
      _throwIfCancelled(requestId);
      throw const PaperAiException('无法连接 DeepSeek 联网搜索，请检查网络后重试。');
    } finally {
      if (identical(_activeClient, client)) _activeClient = null;
      if (_injectedClient == null) client.close();
    }
  }

  @override
  void cancelActiveRequest() {
    if (_activeClient == null) return;
    _cancelledRequest = _requestSerial;
    _activeClient?.close();
    _activeClient = null;
  }

  void _validateConfiguration() {
    if (apiKey.trim().isEmpty) {
      throw const PaperAiException(
        '尚未配置 DeepSeek API Key（DEEPSEEK_API_KEY）。',
      );
    }
  }

  Uri _endpoint() {
    var normalized = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    normalized = normalized.replaceFirst(RegExp(r'/anthropic$'), '');
    return Uri.parse('$normalized/anthropic/v1/messages');
  }

  Map<String, Object> _requestBody(
    PaperRecord paper,
    List<PaperAiMessage> conversation,
  ) {
    return {
      'model': model,
      'max_tokens': 4096,
      'stream': true,
      'system': systemPromptBuilder?.call(paper) ??
          PaperAiPromptBuilder.systemPrompt(paper, webSearch: true),
      'thinking': _reasoningEffort == PaperAiReasoningEffort.none
          ? {'type': 'disabled'}
          : {
              'type': 'enabled',
              'budget_tokens': _thinkingBudget(_reasoningEffort),
            },
      if (_reasoningEffort != PaperAiReasoningEffort.none)
        'output_config': {'effort': _reasoningEffort.apiValue},
      'tools': [
        {
          'type': 'web_search_20250305',
          'name': 'web_search',
          'max_uses': maxSearches,
        },
      ],
      'messages': [
        for (final message in conversation)
          {
            'role': message.fromUser ? 'user' : 'assistant',
            'content': message.content,
          },
      ],
    };
  }

  static int _thinkingBudget(PaperAiReasoningEffort effort) {
    return switch (effort) {
      PaperAiReasoningEffort.none => 0,
      PaperAiReasoningEffort.low => 512,
      PaperAiReasoningEffort.medium => 1024,
      PaperAiReasoningEffort.high => 2048,
      PaperAiReasoningEffort.max => 4096,
    };
  }

  Map<String, dynamic> _decodePayload(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) throw const FormatException();
    return decoded;
  }

  PaperAiStreamChunk _streamChunk(Map<String, dynamic> payload) {
    if (payload['type'] == 'content_block_start') {
      final block = payload['content_block'];
      if (block is! Map) return const PaperAiStreamChunk();
      if (block['type'] == 'server_tool_use' && block['name'] == 'web_search') {
        return const PaperAiStreamChunk(searchStarted: true);
      }
      if (block['type'] == 'web_search_tool_result') {
        return PaperAiStreamChunk(
          sources: _sources(block['content']),
          searchFinished: true,
        );
      }
      return const PaperAiStreamChunk();
    }
    if (payload['type'] != 'content_block_delta') {
      return const PaperAiStreamChunk();
    }
    final delta = payload['delta'];
    if (delta is! Map) return const PaperAiStreamChunk();
    return PaperAiStreamChunk(
      reasoningDelta:
          delta['type'] == 'thinking_delta' && delta['thinking'] is String
              ? delta['thinking'] as String
              : '',
      contentDelta: delta['type'] == 'text_delta' && delta['text'] is String
          ? delta['text'] as String
          : '',
    );
  }

  List<PaperAiSource> _sources(Object? rawContent) {
    if (rawContent is! List) return const [];
    final sources = <PaperAiSource>[];
    for (final item in rawContent.whereType<Map>()) {
      final title = item['title'];
      final url = item['url'];
      if (title is String &&
          title.trim().isNotEmpty &&
          url is String &&
          url.trim().isNotEmpty) {
        sources.add(PaperAiSource(title: title.trim(), url: url.trim()));
      }
    }
    return sources;
  }

  String _apiError(int statusCode, String body) {
    try {
      final payload = _decodePayload(body);
      final error = payload['error'];
      final message = error is Map ? error['message'] : null;
      if (message is String && message.trim().isNotEmpty) {
        return 'DeepSeek 联网搜索失败：${message.trim()}';
      }
    } on FormatException {
      // Fall through to the status based message.
    }
    if (statusCode == 401 || statusCode == 403) {
      return 'DeepSeek 联网搜索鉴权失败，请检查 API Key。';
    }
    if (statusCode == 429) return '联网搜索请求过于频繁，请稍后重试。';
    return 'DeepSeek 联网搜索失败（HTTP $statusCode）。';
  }

  String _eventError(Map<String, dynamic> payload) {
    final error = payload['error'];
    final message = error is Map ? error['message'] : null;
    return message is String && message.trim().isNotEmpty
        ? 'DeepSeek 联网搜索失败：${message.trim()}'
        : 'DeepSeek 联网搜索发生错误。';
  }

  void _throwIfCancelled(int requestId) {
    if (_cancelledRequest == requestId) {
      throw const PaperAiCancelledException();
    }
  }
}
