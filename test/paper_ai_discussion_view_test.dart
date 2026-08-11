import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/chat/domain/chat_ai_service.dart';
import 'package:spark/src/features/chat/domain/chat_context.dart';
import 'package:spark/src/features/chat/domain/chat_message.dart';
import 'package:spark/src/features/chat/domain/chat_session_repository.dart';
import 'package:spark/src/features/chat/presentation/paper_ai_chat_screen.dart';
import 'package:spark/src/features/chat/presentation/paper_ai_discussion_view.dart';

void main() {
  const messages = [
    ChatMessage(fromUser: true, content: '论文问题'),
    ChatMessage(fromUser: false, content: '论文回答'),
  ];

  testWidgets('embedded paper discussion hides edit and delete entries',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PaperAiDiscussionView(
            chatContext: ChatContext(
              id: 'embedded-discussion-test',
              title: '内嵌讨论测试',
              systemPrompt: '回答问题。',
            ),
            aiService: _FakeChatAiService(),
            sessionRepository: _FakeChatSessionRepository(messages: messages),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('paper-ai-user-copy')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('paper-ai-assistant-copy')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('paper-ai-assistant-retry')), findsOneWidget);
    expect(find.byKey(const ValueKey('paper-ai-user-edit')), findsNothing);
    expect(find.byKey(const ValueKey('paper-ai-assistant-more')), findsNothing);
  });

  testWidgets('fullscreen chat keeps edit and delete entries', (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: PaperAiChatScreen(
          chatContext: ChatContext(
            id: 'fullscreen-chat-test',
            title: '全屏聊天测试',
            systemPrompt: '回答问题。',
          ),
          aiService: _FakeChatAiService(),
          sessionRepository: _FakeChatSessionRepository(messages: messages),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('paper-ai-user-edit')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('paper-ai-assistant-more')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('paper-ai-assistant-more')));
    await tester.pumpAndSettle();
    expect(find.text('删除消息'), findsOneWidget);
  });
}

class _FakeChatAiService implements ChatAiService {
  const _FakeChatAiService();

  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async {
    return '回答';
  }
}

class _FakeChatSessionRepository implements ChatSessionRepository {
  const _FakeChatSessionRepository({this.messages = const []});

  final List<ChatMessage> messages;

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<void> clear(String contextId) async {}

  @override
  Future<List<ChatMessage>> load(String contextId) async => messages;

  @override
  Future<List<ChatSessionSummary>> listSessions() async => const [];

  @override
  Future<void> save(String contextId, List<ChatMessage> messages) async {}

  @override
  Future<void> setPinned(String contextId, bool pinned) async {}
}
