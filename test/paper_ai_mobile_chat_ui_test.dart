import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/src/features/chat/application/chat_ai_service.dart';
import 'package:paperflow/src/features/chat/domain/chat_context.dart';
import 'package:paperflow/src/features/chat/domain/chat_message.dart';
import 'package:paperflow/src/features/chat/domain/chat_session_repository.dart';
import 'package:paperflow/src/features/chat/presentation/paper_ai_chat_screen.dart';

void main() {
  testWidgets(
      'mobile chat exposes the RikkaHub-style header and outline toggle',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: PaperAiChatScreen(
          chatContext: const ChatContext(
            id: 'mobile-ui-test',
            title: '问候欢迎',
            systemPrompt: '回答问题。',
          ),
          aiService: const _FakeChatAiService(),
          sessionRepository: _FakeChatSessionRepository(),
          screenTitle: '问候欢迎',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('paper-ai-menu')), findsNothing);
    expect(find.byKey(const ValueKey('paper-ai-back')), findsOneWidget);
    expect(find.byKey(const ValueKey('paper-ai-new-chat')), findsNothing);
    expect(find.text('问候欢迎'), findsNWidgets(2));
    expect(find.text('默认助手 / deepseek-v4-flash (DeepSeek)'), findsNothing);
    expect(
      find.byKey(const ValueKey('paper-ai-outline-toggle')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('paper-ai-composer-surface')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('paper-ai-outline-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('对话大纲'), findsOneWidget);
    expect(find.byKey(const ValueKey('paper-ai-outline')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('paper-ai-outline-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paper-ai-conversation')), findsOneWidget);
  });

  testWidgets(
      'conversation title is editable and subtitle is supplied by session type',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PaperAiChatScreen(
          chatContext: const ChatContext(
            id: 'paper-ui-test',
            title: '论文名称',
            systemPrompt: '回答问题。',
          ),
          aiService: const _FakeChatAiService(),
          sessionRepository: _FakeChatSessionRepository(),
          screenTitle: '初始标题',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('初始标题'), findsOneWidget);
    expect(find.text('论文名称'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('paper-ai-title')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('paper-ai-title-input')),
      '修改后的标题',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('修改后的标题'), findsOneWidget);
    expect(find.text('论文名称'), findsOneWidget);
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
  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<void> clear(String contextId) async {}

  @override
  Future<List<ChatMessage>> load(String contextId) async => const [];

  @override
  Future<List<ChatSessionSummary>> listSessions() async => const [];

  @override
  Future<void> save(String contextId, List<ChatMessage> messages) async {}

  @override
  Future<void> setPinned(String contextId, bool pinned) async {}
}
