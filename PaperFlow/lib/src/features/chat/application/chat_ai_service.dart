import '../domain/chat_context.dart';
import '../domain/chat_message.dart';

enum ChatReasoningEffort {
  none('none', '关闭'),
  low('low', '低'),
  medium('medium', '中'),
  high('high', '高'),
  max('max', '最大');

  const ChatReasoningEffort(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static ChatReasoningEffort fromApiValue(String value) {
    return values.firstWhere(
      (item) => item.apiValue == value.trim().toLowerCase(),
      orElse: () => ChatReasoningEffort.high,
    );
  }
}

abstract interface class ConfigurableChatAiService {
  void setReasoningEffort(ChatReasoningEffort effort);
}

abstract interface class ChatAiService {
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  });
}

class ChatStreamChunk {
  const ChatStreamChunk({
    this.reasoningDelta = '',
    this.contentDelta = '',
    this.sources = const [],
    this.searchStarted = false,
    this.searchFinished = false,
  });

  final String reasoningDelta;
  final String contentDelta;
  final List<ChatSource> sources;
  final bool searchStarted;
  final bool searchFinished;

  bool get isEmpty =>
      reasoningDelta.isEmpty &&
      contentDelta.isEmpty &&
      sources.isEmpty &&
      !searchStarted &&
      !searchFinished;
}

abstract interface class StreamingChatAiService implements ChatAiService {
  Stream<ChatStreamChunk> answerStream({
    required ChatContext context,
    required List<ChatMessage> conversation,
  });
}

abstract interface class CancellableChatAiService implements ChatAiService {
  void cancelActiveRequest();
}

class ChatAiException implements Exception {
  const ChatAiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ChatAiCancelledException extends ChatAiException {
  const ChatAiCancelledException() : super('已停止生成。');
}
