import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../chat/application/chat_ai_service.dart';
import '../../chat/domain/chat_context.dart';
import '../../chat/domain/chat_message.dart';
import '../../ai_settings/domain/deepseek_credential_repository.dart';

const _debugBuildApiKey = bool.fromEnvironment('dart.vm.product')
    ? ''
    : String.fromEnvironment('DEEPSEEK_API_KEY');

class DeepSeekWebSearchAiService
    implements
        ChatAiService,
        StreamingChatAiService,
        CancellableChatAiService,
        ConfigurableChatAiService {
  DeepSeekWebSearchAiService({
    this.apiKey = _debugBuildApiKey,
    this.credentialRepository,
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
      defaultValue: 'high',
    ),
    this.maxSearches = 3,
    this.systemPromptBuilder,
    http.Client? client,
  })  : _reasoningEffort = ChatReasoningEffort.fromApiValue(reasoningEffort),
        _injectedClient = client;

  final String apiKey;
  final DeepSeekCredentialRepository? credentialRepository;
  final String baseUrl;
  final String model;
  final int maxSearches;
  final String Function(ChatContext context)? systemPromptBuilder;
  final http.Client? _injectedClient;
  ChatReasoningEffort _reasoningEffort;

  String get reasoningEffort => _reasoningEffort.apiValue;

  @override
  void setReasoningEffort(ChatReasoningEffort effort) {
    _reasoningEffort = effort;
  }

  http.Client? _activeClient;
  int _requestSerial = 0;
  int? _cancelledRequest;

  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async {
    final content = StringBuffer();
    await for (final chunk in answerStream(
      context: context,
      conversation: conversation,
    )) {
      content.write(chunk.contentDelta);
    }
    if (content.toString().trim().isEmpty) {
      throw const ChatAiException('DeepSeek 联网搜索没有返回回答。');
    }
    return content.toString().trim();
  }

  @override
  Stream<ChatStreamChunk> answerStream({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async* {
    final resolvedApiKey = await _resolveApiKey();
    _validateConfiguration(resolvedApiKey);
    final requestId = ++_requestSerial;
    final client = _injectedClient ?? http.Client();
    _activeClient = client;
    try {
      final request = http.Request('POST', _endpoint())
        ..headers.addAll({
          'x-api-key': resolvedApiKey,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
        })
        ..body = jsonEncode(_requestBody(context, conversation));
      final response =
          await client.send(request).timeout(const Duration(seconds: 60));
      _throwIfCancelled(requestId);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        throw ChatAiException(_apiError(response.statusCode, body));
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
          throw ChatAiException(_eventError(payload));
        }
        final chunk = _streamChunk(payload);
        if (!chunk.isEmpty) yield chunk;
      }
    } on ChatAiCancelledException {
      rethrow;
    } on ChatAiException {
      rethrow;
    } on FormatException {
      throw const ChatAiException('DeepSeek 联网搜索返回了无法解析的数据。');
    } on TimeoutException {
      throw const ChatAiException('DeepSeek 联网搜索响应超时，请稍后重试。');
    } on Exception {
      _throwIfCancelled(requestId);
      throw const ChatAiException('无法连接 DeepSeek 联网搜索，请检查网络后重试。');
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

  Future<String> _resolveApiKey() async {
    try {
      final storedApiKey = await credentialRepository?.readApiKey();
      if (storedApiKey != null && storedApiKey.trim().isNotEmpty) {
        return storedApiKey.trim();
      }
      return apiKey.trim();
    } on DeepSeekCredentialException catch (error) {
      throw ChatAiException(error.message);
    }
  }

  void _validateConfiguration(String resolvedApiKey) {
    if (resolvedApiKey.isEmpty) {
      throw const ChatAiException(
        '尚未配置 DeepSeek API Key，请前往“我的”完成配置。',
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
    ChatContext context,
    List<ChatMessage> conversation,
  ) {
    return {
      'model': model,
      'max_tokens': 4096,
      'stream': true,
      'system': systemPromptBuilder?.call(context) ??
          context.promptFor(webSearch: true),
      'thinking': _reasoningEffort == ChatReasoningEffort.none
          ? {'type': 'disabled'}
          : {
              'type': 'enabled',
              'budget_tokens': _thinkingBudget(_reasoningEffort),
            },
      if (_reasoningEffort != ChatReasoningEffort.none)
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

  static int _thinkingBudget(ChatReasoningEffort effort) {
    return switch (effort) {
      ChatReasoningEffort.none => 0,
      ChatReasoningEffort.low => 512,
      ChatReasoningEffort.medium => 1024,
      ChatReasoningEffort.high => 2048,
      ChatReasoningEffort.max => 4096,
    };
  }

  Map<String, dynamic> _decodePayload(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) throw const FormatException();
    return decoded;
  }

  ChatStreamChunk _streamChunk(Map<String, dynamic> payload) {
    if (payload['type'] == 'content_block_start') {
      final block = payload['content_block'];
      if (block is! Map) return const ChatStreamChunk();
      if (block['type'] == 'server_tool_use' && block['name'] == 'web_search') {
        return const ChatStreamChunk(searchStarted: true);
      }
      if (block['type'] == 'web_search_tool_result') {
        return ChatStreamChunk(
          sources: _sources(block['content']),
          searchFinished: true,
        );
      }
      return const ChatStreamChunk();
    }
    if (payload['type'] != 'content_block_delta') {
      return const ChatStreamChunk();
    }
    final delta = payload['delta'];
    if (delta is! Map) return const ChatStreamChunk();
    return ChatStreamChunk(
      reasoningDelta:
          delta['type'] == 'thinking_delta' && delta['thinking'] is String
              ? delta['thinking'] as String
              : '',
      contentDelta: delta['type'] == 'text_delta' && delta['text'] is String
          ? delta['text'] as String
          : '',
    );
  }

  List<ChatSource> _sources(Object? rawContent) {
    if (rawContent is! List) return const [];
    final sources = <ChatSource>[];
    for (final item in rawContent.whereType<Map>()) {
      final title = item['title'];
      final url = item['url'];
      if (title is String &&
          title.trim().isNotEmpty &&
          url is String &&
          url.trim().isNotEmpty) {
        sources.add(ChatSource(title: title.trim(), url: url.trim()));
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
      throw const ChatAiCancelledException();
    }
  }
}
