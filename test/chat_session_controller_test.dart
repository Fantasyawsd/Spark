import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spark/spark.dart';
import 'package:spark/src/features/chat/application/chat_session_controller.dart';
import 'package:spark/src/features/chat/data/in_memory_chat_session_settings_repository.dart';

void main() {
  group('ChatSessionController', () {
    test('separates main chat, filters unknown contexts and sorts entries',
        () async {
      final repository = _FakeChatSessionRepository([
        _session('paper-1', minute: 1),
        _session('unknown', minute: 5, pinned: true),
        _session('main', minute: 2),
        _session('paper-2', minute: 3, pinned: true),
        _session('paper-3', minute: 4),
      ]);
      final controller = _controller(repository);
      addTearDown(controller.dispose);

      await controller.refresh();

      expect(controller.mainSession?.contextId, 'main');
      expect(
        controller.entries.map((entry) => entry.context.id),
        ['paper-2', 'paper-3', 'paper-1'],
      );
      expect(controller.entries.first.context.title, 'Paper 2');
      expect(controller.loading, isFalse);
      expect(controller.error, isNull);
    });

    test('updates contexts without reloading sessions', () async {
      final repository = _FakeChatSessionRepository([
        _session('paper-1', minute: 1),
        _session('paper-4', minute: 2),
      ]);
      final controller = _controller(repository);
      addTearDown(controller.dispose);
      await controller.refresh();

      controller.updateContexts(const [
        ChatContextSummary(id: 'paper-4', title: 'Paper 4'),
      ]);

      expect(controller.entries.single.context.id, 'paper-4');
      expect(repository.listCalls, 1);
    });

    test('toggles pin and deletes through repository commands', () async {
      final repository = _FakeChatSessionRepository([
        _session('paper-1', minute: 1),
        _session('paper-2', minute: 2),
      ]);
      final controller = _controller(repository);
      addTearDown(controller.dispose);
      await controller.refresh();

      await controller.togglePinned('paper-1');

      expect(repository.pinnedChanges, [('paper-1', true)]);
      expect(controller.entries.first.context.id, 'paper-1');
      expect(controller.entries.first.session.pinned, isTrue);

      await controller.delete('paper-1');

      expect(repository.clearedIds, ['paper-1']);
      expect(controller.entries.single.context.id, 'paper-2');
    });

    test('deleting a chat also clears its session settings', () async {
      final repository = _FakeChatSessionRepository([
        _session('paper-1', minute: 1),
      ]);
      final settingsRepository = InMemoryChatSessionSettingsRepository();
      await settingsRepository.save(
        'paper-1',
        const ChatSessionSettings(customSystemPrompt: '仅用于这一会话'),
      );
      final controller = _controller(
        repository,
        settingsRepository: settingsRepository,
      );
      addTearDown(controller.dispose);
      await controller.refresh();

      await controller.delete('paper-1');

      expect(repository.clearedIds, ['paper-1']);
      expect(
        (await settingsRepository.load('paper-1')).hasCustomizations,
        isFalse,
      );
    });

    test('does not delete messages when session settings cleanup fails',
        () async {
      final repository = _FakeChatSessionRepository([
        _session('paper-1', minute: 1),
      ]);
      final controller = _controller(
        repository,
        settingsRepository: _FailingSettingsRepository(),
      );
      addTearDown(controller.dispose);
      await controller.refresh();

      await controller.delete('paper-1');

      expect(repository.clearedIds, isEmpty);
      expect(controller.entries.single.context.id, 'paper-1');
      expect(controller.error, '无法删除会话设置。');
    });

    test('exposes repository failures as controller errors', () async {
      final repository = _FakeChatSessionRepository(
        const [],
        listError: const ChatSessionPersistenceException('读取失败'),
      );
      final controller = _controller(repository);
      addTearDown(controller.dispose);

      await controller.refresh();

      expect(controller.error, '读取失败');
      expect(controller.loading, isFalse);
      expect(controller.entries, isEmpty);
    });

    test('maps an unexpected refresh failure without leaking the future error',
        () async {
      final repository = _UnexpectedListFailureRepository();
      final controller = _controller(repository);
      addTearDown(controller.dispose);

      await controller.refresh();

      expect(controller.error, '无法读取 AI 会话列表。');
      expect(controller.loading, isFalse);
    });

    test('does not notify after disposal while refresh is pending', () async {
      final repository = _DeferredChatSessionRepository();
      final controller = _controller(repository);
      var notifications = 0;
      controller.addListener(() => notifications++);

      final refresh = controller.refresh();
      expect(notifications, 1);
      controller.dispose();
      repository.complete([_session('paper-1', minute: 1)]);

      await refresh;
      expect(notifications, 1);
    });

    test('refreshes automatically when the repository emits changes', () async {
      final repository = _FakeChatSessionRepository([
        _session('paper-1', minute: 1),
      ]);
      final controller = _controller(repository);
      addTearDown(controller.dispose);
      await controller.refresh();
      expect(controller.entries.single.context.id, 'paper-1');

      repository.updateSessions([_session('paper-2', minute: 2)]);
      repository.emitChanges();
      await pumpEventQueue();

      expect(controller.entries.single.context.id, 'paper-2');
      expect(repository.listCalls, greaterThan(1));
    });
  });
}

ChatSessionController _controller(
  ChatSessionRepository repository, {
  ChatSessionSettingsRepository? settingsRepository,
}) {
  return ChatSessionController(
    repository: repository,
    settingsRepository: settingsRepository,
    mainSessionId: 'main',
    contexts: const [
      ChatContextSummary(id: 'paper-1', title: 'Paper 1'),
      ChatContextSummary(id: 'paper-2', title: 'Paper 2'),
      ChatContextSummary(id: 'paper-3', title: 'Paper 3'),
    ],
  );
}

ChatSessionSummary _session(
  String contextId, {
  required int minute,
  bool pinned = false,
}) {
  return ChatSessionSummary(
    contextId: contextId,
    messageCount: 2,
    preview: 'preview $contextId',
    updatedAt: DateTime.utc(2026, 8, 1, 12, minute),
    pinned: pinned,
  );
}

class _FakeChatSessionRepository implements ChatSessionRepository {
  _FakeChatSessionRepository(
    List<ChatSessionSummary> sessions, {
    this.listError,
  }) : _sessions = List.of(sessions);

  final ChatSessionPersistenceException? listError;
  final List<(String, bool)> pinnedChanges = [];
  final List<String> clearedIds = [];
  final _changesController = StreamController<void>.broadcast();
  List<ChatSessionSummary> _sessions;
  int listCalls = 0;

  @override
  Stream<void> get changes => _changesController.stream;

  void updateSessions(List<ChatSessionSummary> sessions) {
    _sessions = List.of(sessions);
  }

  void emitChanges() => _changesController.add(null);

  @override
  Future<List<ChatSessionSummary>> listSessions() async {
    listCalls++;
    final error = listError;
    if (error != null) throw error;
    return List.unmodifiable(_sessions);
  }

  @override
  Future<void> setPinned(String contextId, bool pinned) async {
    pinnedChanges.add((contextId, pinned));
    _sessions = [
      for (final session in _sessions)
        if (session.contextId == contextId)
          ChatSessionSummary(
            contextId: session.contextId,
            messageCount: session.messageCount,
            preview: session.preview,
            updatedAt: session.updatedAt,
            pinned: pinned,
          )
        else
          session,
    ];
  }

  @override
  Future<void> clear(String contextId) async {
    clearedIds.add(contextId);
    _sessions = _sessions
        .where((session) => session.contextId != contextId)
        .toList(growable: false);
  }

  @override
  Future<List<ChatMessage>> load(String contextId) async => const [];

  @override
  Future<void> save(String contextId, List<ChatMessage> messages) async {}
}

class _DeferredChatSessionRepository implements ChatSessionRepository {
  final Completer<List<ChatSessionSummary>> _completer = Completer();

  void complete(List<ChatSessionSummary> sessions) =>
      _completer.complete(sessions);

  @override
  Stream<void> get changes => Stream.empty();

  @override
  Future<List<ChatSessionSummary>> listSessions() => _completer.future;

  @override
  Future<void> clear(String contextId) async {}

  @override
  Future<List<ChatMessage>> load(String contextId) async => const [];

  @override
  Future<void> save(String contextId, List<ChatMessage> messages) async {}

  @override
  Future<void> setPinned(String contextId, bool pinned) async {}
}

class _UnexpectedListFailureRepository implements ChatSessionRepository {
  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<void> clear(String contextId) async {}

  @override
  Future<List<ChatMessage>> load(String contextId) async => const [];

  @override
  Future<List<ChatSessionSummary>> listSessions() async {
    throw StateError('unexpected list failure');
  }

  @override
  Future<void> save(String contextId, List<ChatMessage> messages) async {}

  @override
  Future<void> setPinned(String contextId, bool pinned) async {}
}

class _FailingSettingsRepository implements ChatSessionSettingsRepository {
  @override
  Future<void> clear(String contextId) async {
    throw const ChatSessionSettingsPersistenceException('无法删除会话设置。');
  }

  @override
  Future<ChatSessionSettings> load(String contextId) async =>
      ChatSessionSettings.empty;

  @override
  Future<void> save(
    String contextId,
    ChatSessionSettings settings,
  ) async {}
}
