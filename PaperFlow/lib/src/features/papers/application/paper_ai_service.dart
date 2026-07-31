import '../domain/paper.dart';

class PaperAiMessage {
  const PaperAiMessage({required this.fromUser, required this.content});

  final bool fromUser;
  final String content;
}

abstract interface class PaperAiService {
  Future<String> answer({
    required PaperRecord paper,
    required List<PaperAiMessage> conversation,
  });
}

class PaperAiException implements Exception {
  const PaperAiException(this.message);

  final String message;

  @override
  String toString() => message;
}
