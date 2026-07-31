import '../domain/paper.dart';

enum PaperAiReasoningEffort {
  none('none', '关闭'),
  low('low', '低'),
  medium('medium', '中'),
  high('high', '高'),
  max('max', '最大');

  const PaperAiReasoningEffort(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static PaperAiReasoningEffort fromApiValue(String value) {
    return values.firstWhere(
      (item) => item.apiValue == value.trim().toLowerCase(),
      orElse: () => PaperAiReasoningEffort.high,
    );
  }
}

abstract interface class ConfigurablePaperAiService {
  void setReasoningEffort(PaperAiReasoningEffort effort);
}

class PaperAiMessage {
  const PaperAiMessage({
    required this.fromUser,
    required this.content,
    this.reasoningContent = '',
    this.sources = const [],
  });

  final bool fromUser;
  final String content;
  final String reasoningContent;
  final List<PaperAiSource> sources;

  PaperAiMessage copyWith({
    String? content,
    String? reasoningContent,
    List<PaperAiSource>? sources,
  }) {
    return PaperAiMessage(
      fromUser: fromUser,
      content: content ?? this.content,
      reasoningContent: reasoningContent ?? this.reasoningContent,
      sources: sources ?? this.sources,
    );
  }
}

class PaperAiSource {
  const PaperAiSource({required this.title, required this.url});

  final String title;
  final String url;
}

abstract interface class PaperAiService {
  Future<String> answer({
    required PaperRecord paper,
    required List<PaperAiMessage> conversation,
  });
}

class PaperAiStreamChunk {
  const PaperAiStreamChunk({
    this.reasoningDelta = '',
    this.contentDelta = '',
    this.sources = const [],
    this.searchStarted = false,
    this.searchFinished = false,
  });

  final String reasoningDelta;
  final String contentDelta;
  final List<PaperAiSource> sources;
  final bool searchStarted;
  final bool searchFinished;

  bool get isEmpty =>
      reasoningDelta.isEmpty &&
      contentDelta.isEmpty &&
      sources.isEmpty &&
      !searchStarted &&
      !searchFinished;
}

abstract interface class StreamingPaperAiService implements PaperAiService {
  Stream<PaperAiStreamChunk> answerStream({
    required PaperRecord paper,
    required List<PaperAiMessage> conversation,
  });
}

abstract interface class CancellablePaperAiService implements PaperAiService {
  void cancelActiveRequest();
}

class PaperAiException implements Exception {
  const PaperAiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PaperAiCancelledException extends PaperAiException {
  const PaperAiCancelledException() : super('已停止生成。');
}
