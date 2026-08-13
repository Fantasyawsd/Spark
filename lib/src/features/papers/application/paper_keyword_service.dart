import 'dart:convert';

import '../../chat/chat.dart';
import '../domain/paper.dart';
import '../domain/paper_keyword_record.dart';
import 'paper_content_fingerprint.dart';

const paperKeywordPromptVersion = 1;
const _fingerprintSeparator = '|spark-keywords|';

class PaperKeywordGenerator {
  const PaperKeywordGenerator(this._service);

  final ChatAiService _service;

  Future<List<String>> generate(Paper paper) async {
    final response = await _service.answer(
      context: ChatContext(
        id: 'paper-keywords:${paper.id}',
        title: paper.title,
        systemPrompt: _systemPrompt,
      ),
      conversation: [
        ChatMessage(
          fromUser: true,
          content: '''标题：${paper.title}

Abstract：
${paper.content.originalAbstractMarkdown}''',
        ),
      ],
    );
    return PaperKeywordParser.parse(response);
  }

  static const _systemPrompt = '''
你是论文关键词提取器。只根据用户提供的论文标题与 Abstract，提取 5 至 12 个内容关键词。不要使用 arXiv 分类充数，不要解释。仅返回 JSON 字符串数组。''';
}

class PaperKeywordParser {
  const PaperKeywordParser._();

  static List<String> parse(String response) {
    final trimmed = response.trim();
    final jsonText = _jsonArrayText(trimmed);
    List<Object?> values;
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! List) throw const FormatException();
      values = decoded.cast<Object?>();
    } on FormatException {
      throw const PaperKeywordGenerationException('关键词生成结果格式无效，请重试。');
    }

    final seen = <String>{};
    final keywords = <String>[];
    for (final value in values) {
      if (value is! String) continue;
      final keyword = value.trim();
      if (keyword.isEmpty || !seen.add(keyword.toLowerCase())) continue;
      keywords.add(keyword);
    }
    if (keywords.length < 5 || keywords.length > 12) {
      throw const PaperKeywordGenerationException('关键词数量应为 5 至 12 个，请重试。');
    }
    return List.unmodifiable(keywords);
  }

  static String _jsonArrayText(String value) {
    if (!value.startsWith('```')) return value;
    final firstLineEnd = value.indexOf('\n');
    final lastFence = value.lastIndexOf('```');
    if (firstLineEnd < 0 || lastFence <= firstLineEnd) return value;
    return value.substring(firstLineEnd + 1, lastFence).trim();
  }
}

class PaperKeywordGenerationException implements Exception {
  const PaperKeywordGenerationException(this.message);

  final String message;

  @override
  String toString() => message;
}

String paperKeywordInputFingerprint(Paper paper) {
  return paperContentFingerprint(paper, namespace: _fingerprintSeparator);
}

bool isPaperKeywordRecordFresh(PaperKeywordRecord record, Paper paper) {
  return record.paperId == paper.id &&
      record.promptVersion == paperKeywordPromptVersion &&
      record.inputFingerprint == paperKeywordInputFingerprint(paper) &&
      record.keywords.length >= 5 &&
      record.keywords.length <= 12;
}
