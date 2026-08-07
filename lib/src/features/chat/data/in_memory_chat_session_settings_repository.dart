import '../domain/chat_session_settings.dart';

/// 内存实现：用于预览、测试与未装配持久化的环境。
class InMemoryChatSessionSettingsRepository
    implements ChatSessionSettingsRepository {
  final Map<String, ChatSessionSettings> _store = {};

  @override
  Future<ChatSessionSettings> load(String contextId) async =>
      _store[contextId] ?? ChatSessionSettings.empty;

  @override
  Future<void> save(String contextId, ChatSessionSettings settings) async {
    _store[contextId] = settings;
  }

  @override
  Future<void> clear(String contextId) async {
    _store.remove(contextId);
  }
}
