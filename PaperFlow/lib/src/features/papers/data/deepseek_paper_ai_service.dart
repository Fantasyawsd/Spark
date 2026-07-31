import 'dart:convert';

import 'package:http/http.dart' as http;

import '../application/paper_ai_service.dart';
import '../domain/paper.dart';

class DeepSeekPaperAiService implements PaperAiService {
  DeepSeekPaperAiService({
    this.apiKey = const String.fromEnvironment('DEEPSEEK_API_KEY'),
    this.baseUrl = const String.fromEnvironment(
      'DEEPSEEK_BASE_URL',
      defaultValue: 'https://api.deepseek.com',
    ),
    this.model = const String.fromEnvironment(
      'DEEPSEEK_MODEL',
      defaultValue: 'deepseek-chat',
    ),
    http.Client? client,
  }) : _client = client;

  final String apiKey;
  final String baseUrl;
  final String model;
  final http.Client? _client;

  @override
  Future<String> answer({
    required PaperRecord paper,
    required List<PaperAiMessage> conversation,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw const PaperAiException(
        '尚未配置 DeepSeek API Key，请使用 --dart-define=DEEPSEEK_API_KEY=你的密钥启动应用。',
      );
    }

    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(
            _endpoint(),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {
                  'role': 'system',
                  'content': _systemPrompt(paper),
                },
                for (final message in conversation)
                  {
                    'role': message.fromUser ? 'user' : 'assistant',
                    'content': message.content,
                  },
              ],
              'stream': false,
              'temperature': 0.2,
            }),
          )
          .timeout(const Duration(seconds: 45));

      final payload = _decodePayload(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PaperAiException(_apiError(response.statusCode, payload));
      }

      final choices = payload['choices'];
      if (choices is! List || choices.isEmpty) {
        throw const PaperAiException('DeepSeek 返回了空响应，请稍后重试。');
      }
      final firstChoice = choices.first;
      final message = firstChoice is Map ? firstChoice['message'] : null;
      final content = message is Map ? message['content'] : null;
      if (content is! String || content.trim().isEmpty) {
        throw const PaperAiException('DeepSeek 响应格式异常，请稍后重试。');
      }
      return content.trim();
    } on PaperAiException {
      rethrow;
    } on FormatException {
      throw const PaperAiException('DeepSeek 返回了无法解析的数据。');
    } on Exception {
      throw const PaperAiException('无法连接 DeepSeek，请检查网络后重试。');
    } finally {
      if (_client == null) client.close();
    }
  }

  Uri _endpoint() {
    final normalized = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$normalized/chat/completions');
  }

  Map<String, dynamic> _decodePayload(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) throw const FormatException();
    return decoded;
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

  String _systemPrompt(PaperRecord paper) {
    return '''
你是 PaperFlow 的论文阅读助手。请严格基于给定论文信息回答，使用用户的语言，保持准确、简洁；不确定时明确说明。回答使用 Markdown，但不要使用 HTML。

# 论文
标题：${paper.title}
作者：${paper.authors}
第一单位：${paper.firstAffiliation}
会议：${paper.venue}
主题：${paper.topics.join(', ')}

## 摘要
${paper.abstractText}

## 中文摘要
${paper.chineseAbstractMarkdown}
''';
  }
}
