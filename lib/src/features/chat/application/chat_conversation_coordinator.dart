import '../domain/chat_ai_service.dart';
import '../domain/chat_context.dart';
import '../domain/chat_session_repository.dart';
import '../domain/chat_session_settings.dart';
import 'chat_conversation_controller.dart';

/// Owns persistent chat conversations for as long as the application shell
/// remains alive. Presentation widgets may attach to a conversation without
/// taking ownership of its active request.
class ChatConversationCoordinator {
  ChatConversationCoordinator({
    required ChatSessionRepository sessionRepository,
    ChatSessionSettingsRepository? settingsRepository,
  })  : _sessionRepository = sessionRepository,
        _settingsRepository = settingsRepository;

  final ChatSessionRepository _sessionRepository;
  final ChatSessionSettingsRepository? _settingsRepository;
  final Map<String, ChatConversationController> _conversations = {};
  bool _disposed = false;

  ChatConversationController conversation({
    required ChatContext context,
    required ChatAiService service,
    ChatAiService? webSearchService,
  }) {
    if (_disposed) {
      throw StateError('ChatConversationCoordinator has been disposed.');
    }

    final existing = _conversations[context.id];
    if (existing != null) {
      existing.replaceContext(context);
      return existing;
    }

    final created = ChatConversationController(
      context: context,
      service: service,
      webSearchService: webSearchService,
      sessionRepository: _sessionRepository,
      settingsRepository: _settingsRepository,
    );
    _conversations[context.id] = created;
    created.initialize();
    return created;
  }

  Future<void> remove(String contextId) async {
    final conversation = _conversations.remove(contextId);
    if (conversation == null) return;
    conversation.dispose();
    await conversation.flushPendingWrites();
  }

  Future<void> removeAll() async {
    final conversations = _conversations.values.toList(growable: false);
    _conversations.clear();
    for (final conversation in conversations) {
      conversation.dispose();
    }
    await Future.wait(
      conversations.map((conversation) => conversation.flushPendingWrites()),
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final conversation in _conversations.values) {
      conversation.dispose();
    }
    _conversations.clear();
  }
}
