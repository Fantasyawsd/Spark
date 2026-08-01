class ChatContext {
  const ChatContext({
    required this.id,
    required this.title,
    required this.systemPrompt,
    this.subtitle,
    this.webSearchSystemPrompt,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String systemPrompt;
  final String? webSearchSystemPrompt;

  String promptFor({required bool webSearch}) {
    if (webSearch) return webSearchSystemPrompt ?? systemPrompt;
    return systemPrompt;
  }
}
