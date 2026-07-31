import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../application/paper_ai_service.dart';
import '../application/paper_ai_prompt_builder.dart';
import '../domain/paper.dart';

class DeepSeekPaperAiService
    implements
        PaperAiService,
        StreamingPaperAiService,
        CancellablePaperAiService,
        ConfigurablePaperAiService {
  DeepSeekPaperAiService({
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
    this.thinkingEnabled = true,
    this.systemPromptBuilder,
    http.Client? client,
  })  : _reasoningEffort = thinkingEnabled
            ? PaperAiReasoningEffort.fromApiValue(reasoningEffort)
            : PaperAiReasoningEffort.none,
        _injectedClient = client;

  final String apiKey;
  final String baseUrl;
  final String model;
  final bool thinkingEnabled;
  final String Function(PaperRecord paper)? systemPromptBuilder;
  final http.Client? _injectedClient;
  PaperAiReasoningEffort _reasoningEffort;

  String get reasoningEffort => _reasoningEffort.apiValue;

  @override
  void setReasoningEffort(PaperAiReasoningEffort effort) {
    if (thinkingEnabled) _reasoningEffort = effort;
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
      throw const PaperAiException('DeepSeek 返回了空响应，请稍后重试。');
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
        final payload = _decodePayload(body);
        throw PaperAiException(_apiError(response.statusCode, payload));
      }

      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        _throwIfCancelled(requestId);
        if (!line.startsWith('data:')) continue;
        final data = line.substring(5).trim();
        if (data.isEmpty) continue;
        final payload = _decodePayload(data);
        if (payload['type'] == 'error' || payload['error'] != null) {
          throw PaperAiException(_apiError(500, payload));
        }
        final chunk = _streamChunk(payload);
        if (!chunk.isEmpty) yield chunk;
      }
    } on PaperAiCancelledException {
      rethrow;
    } on PaperAiException {
      rethrow;
    } on FormatException {
      throw const PaperAiException('DeepSeek 返回了无法解析的数据。');
    } on TimeoutException {
      throw const PaperAiException('DeepSeek 响应超时，请稍后重试。');
    } on Exception {
      _throwIfCancelled(requestId);
      throw const PaperAiException('无法连接 DeepSeek，请检查网络后重试。');
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
        '尚未配置 DeepSeek API Key（DEEPSEEK_API_KEY），请使用本地 DeepSeek 启动脚本运行应用。',
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
          PaperAiPromptBuilder.systemPrompt(paper),
      'thinking':
          !thinkingEnabled || _reasoningEffort == PaperAiReasoningEffort.none
              ? {'type': 'disabled'}
              : {
                  'type': 'enabled',
                  'budget_tokens': _thinkingBudget(_reasoningEffort),
                },
      if (thinkingEnabled && _reasoningEffort != PaperAiReasoningEffort.none)
        'output_config': {'effort': _reasoningEffort.apiValue},
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

  String _apiError(int statusCode, Map<String, dynamic> payload) {
    final error = payload['error'];
    final apiMessage = error is Map ? error['message'] : null;
    if (statusCode == 401 || statusCode == 403) {
      return 'DeepSeek 鉴权失败，请检查 API Key。';
    }
    if (statusCode == 429) {
      return 'DeepSeek 请求过于频繁或额度不足，请稍后重试。';
    }
    if (apiMessage is String && apiMessage.trim().isNotEmpty) {
      return 'DeepSeek 请求失败：${apiMessage.trim()}';
    }
    return 'DeepSeek 请求失败（HTTP $statusCode）。';
  }

  void _throwIfCancelled(int requestId) {
    if (_cancelledRequest == requestId) {
      throw const PaperAiCancelledException();
    }
  }
}
