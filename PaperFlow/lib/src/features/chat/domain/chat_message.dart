class ChatMessage {
  const ChatMessage({
    required this.fromUser,
    required this.content,
    this.reasoningContent = '',
    this.sources = const [],
  });

  final bool fromUser;
  final String content;
  final String reasoningContent;
  final List<ChatSource> sources;

  ChatMessage copyWith({
    String? content,
    String? reasoningContent,
    List<ChatSource>? sources,
  }) {
    return ChatMessage(
      fromUser: fromUser,
      content: content ?? this.content,
      reasoningContent: reasoningContent ?? this.reasoningContent,
      sources: sources ?? this.sources,
    );
  }
}

class ChatSource {
  const ChatSource({required this.title, required this.url});

  final String title;
  final String url;
}
