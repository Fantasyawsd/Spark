import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/chat/application/chat_conversation_controller.dart';
import 'package:spark/src/features/chat/application/chat_session_controller.dart';
import 'package:spark/src/features/chat/application/main_ai_chat_definition.dart';
import 'package:spark/src/features/chat/data/in_memory_chat_session_repository.dart';
import 'package:spark/src/features/chat/domain/chat_ai_service.dart';
import 'package:spark/src/features/chat/domain/chat_context.dart';
import 'package:spark/src/features/chat/domain/chat_message.dart';
import 'package:spark/src/features/chat/domain/chat_session_repository.dart';
import 'package:spark/src/features/chat/presentation/ai_chat_home_screen.dart';
import 'package:spark/src/features/chat/presentation/main_ai_chat_screen.dart';

void main() {
  testWidgets('ChatPaper home transitions from loading to its empty state', (
    tester,
  ) async {
    final repository = _PendingSessionRepository();
    final controller = ChatSessionController(
      repository: repository,
      mainSessionId: MainAiChatDefinition.sessionId,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: AiChatHomeScreen(chatSessionController: controller)),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.complete(const []);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('main-ai-chat')), findsOneWidget);
    expect(find.textContaining('暂无论文解读会话'), findsOneWidget);
  });

  testWidgets('ChatPaper home opens the pinned main chat card', (tester) async {
    final repository = InMemoryChatSessionRepository();
    final controller = ChatSessionController(
      repository: repository,
      mainSessionId: MainAiChatDefinition.sessionId,
    );
    addTearDown(controller.dispose);
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: AiChatHomeScreen(
          chatSessionController: controller,
          onOpenMainChat: () async => opened = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('main-ai-chat')));
    await tester.pump();

    expect(opened, isTrue);
    expect(find.text('Spark 主聊天'), findsOneWidget);
  });

  testWidgets('main chat uses its stable context and research welcome copy', (
    tester,
  ) async {
    final service = _CapturingChatAiService();
    final repository = InMemoryChatSessionRepository();
    final conversation = ChatConversationController(
      context: MainAiChatDefinition.context,
      service: service,
      sessionRepository: repository,
    );
    addTearDown(conversation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MainAiChatScreen(
          aiService: service,
          sessionRepository: repository,
          conversationController: conversation,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('主聊天'), findsOneWidget);
    expect(find.text('今天想研究什么？'), findsOneWidget);
    expect(find.textContaining('跨论文提问'), findsOneWidget);
    expect(conversation.context.id, MainAiChatDefinition.sessionId);
    expect(conversation.context.title, 'Spark 主聊天');
  });
}

class _PendingSessionRepository implements ChatSessionRepository {
  final Completer<List<ChatSessionSummary>> _sessions = Completer();

  void complete(List<ChatSessionSummary> sessions) =>
      _sessions.complete(sessions);

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<void> clear(String contextId) async {}

  @override
  Future<List<ChatMessage>> load(String contextId) async => const [];

  @override
  Future<List<ChatSessionSummary>> listSessions() => _sessions.future;

  @override
  Future<void> save(String contextId, List<ChatMessage> messages) async {}

  @override
  Future<void> setPinned(String contextId, bool pinned) async {}
}

class _CapturingChatAiService implements ChatAiService {
  ChatContext? context;

  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async {
    this.context = context;
    return 'answer';
  }
}
