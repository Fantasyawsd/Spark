import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/core/diagnostics/diagnostics.dart';
import 'package:spark/src/features/chat/application/chat_conversation_settings_state.dart';
import 'package:spark/src/features/chat/domain/chat_session_settings.dart';

void main() {
  test('a pending load cannot overwrite a newer local update', () async {
    final repository = _PendingSettingsRepository();
    final state = ChatConversationSettingsState(
      contextId: 'session-1',
      repository: repository,
      isDisposed: () => false,
      notify: () {},
    );

    final loading = state.load();
    await state.update(
      const ChatSessionSettings(customSystemPrompt: 'new setting'),
    );
    repository.completeLoad(
      const ChatSessionSettings(customSystemPrompt: 'stale setting'),
    );
    await loading;

    expect(state.value.customSystemPrompt, 'new setting');
  });

  test(
    'save failures keep local settings and emit the settings operation',
    () async {
      final events = <SparkDiagnosticEvent>[];
      final state = ChatConversationSettingsState(
        contextId: 'session-1',
        repository: const _FailingSettingsRepository(),
        isDisposed: () => false,
        notify: () {},
      );

      await SparkDiagnostics.runWithSink(
        events.add,
        () => state.update(
          const ChatSessionSettings(customSystemPrompt: 'local setting'),
        ),
      );

      expect(state.value.customSystemPrompt, 'local setting');
      expect(state.persistenceError, '无法保存会话设置。');
      expect(events.map((event) => event.operation), [
        SparkDiagnosticOperation.chatConversationSettingsSave,
      ]);
    },
  );
}

class _PendingSettingsRepository implements ChatSessionSettingsRepository {
  final Completer<ChatSessionSettings> _load = Completer();

  void completeLoad(ChatSessionSettings settings) => _load.complete(settings);

  @override
  Future<void> clear(String contextId) async {}

  @override
  Future<ChatSessionSettings> load(String contextId) => _load.future;

  @override
  Future<void> save(String contextId, ChatSessionSettings settings) async {}
}

class _FailingSettingsRepository implements ChatSessionSettingsRepository {
  const _FailingSettingsRepository();

  @override
  Future<void> clear(String contextId) async {}

  @override
  Future<ChatSessionSettings> load(String contextId) async =>
      ChatSessionSettings.empty;

  @override
  Future<void> save(String contextId, ChatSessionSettings settings) async {
    throw const ChatSessionSettingsPersistenceException('无法保存会话设置。');
  }
}
