enum ChatMessageStatus { complete, cancelled, failed }

class ChatMessage {
  const ChatMessage({
    required this.fromUser,
    required this.content,
    this.reasoningContent = '',
    this.sources = const [],
    this.status = ChatMessageStatus.complete,
  });

  final bool fromUser;
  final String content;
  final String reasoningContent;
  final List<ChatSource> sources;
  final ChatMessageStatus status;

  ChatMessage copyWith({
    String? content,
    String? reasoningContent,
    List<ChatSource>? sources,
    ChatMessageStatus? status,
  }) {
    return ChatMessage(
      fromUser: fromUser,
      content: content ?? this.content,
      reasoningContent: reasoningContent ?? this.reasoningContent,
      sources: sources ?? this.sources,
      status: status ?? this.status,
    );
  }
}

class ChatSource {
  const ChatSource({required this.title, required this.url});

  final String title;
  final String url;
}
