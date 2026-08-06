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
      'deleting an assistant enters multi-selection with its user prompt',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: PaperAiChatScreen(
          chatContext: const ChatContext(
            id: 'selection-ui-test',
            title: '选择消息测试',
            systemPrompt: '回答问题。',
          ),
          aiService: const _FakeChatAiService(),
          sessionRepository: const _FakeChatSessionRepository(
            messages: [
              ChatMessage(fromUser: true, content: '原始问题'),
              ChatMessage(fromUser: false, content: '回答内容'),
            ],
          ),
          screenTitle: '选择消息测试',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('paper-ai-assistant-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除消息'));
    await tester.pumpAndSettle();

    expect(find.text('选择消息'), findsOneWidget);
    expect(find.text('已选择 2 条消息'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    expect(
        find.byKey(const ValueKey('paper-ai-composer-surface')), findsNothing);
  });

  testWidgets('retry action regenerates the latest assistant answer in place',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final service = _QueueUiChatAiService(['重新生成后的回答']);
    await tester.pumpWidget(
      MaterialApp(
        home: PaperAiChatScreen(
          chatContext: const ChatContext(
            id: 'retry-ui-test',
            title: '重试测试',
            systemPrompt: '回答问题。',
          ),
          aiService: service,
          sessionRepository: const _FakeChatSessionRepository(
            messages: [
              ChatMessage(fromUser: true, content: '原始问题'),
              ChatMessage(fromUser: false, content: '旧回答'),
            ],
          ),
          screenTitle: '重试测试',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('重新生成'));
    await tester.pumpAndSettle();

    expect(find.text('旧回答'), findsNothing);
    expect(find.text('重新生成后的回答'), findsOneWidget);
    expect(service.conversations.single, hasLength(1));
    expect(service.conversations.single.single.content, '原始问题');
  });

  testWidgets(
      'editing the latest prompt replaces its answer instead of appending a turn',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final service = _QueueUiChatAiService(['重新生成后的回答']);
    await tester.pumpWidget(
      MaterialApp(
        home: PaperAiChatScreen(
          chatContext: const ChatContext(
            id: 'edit-prompt-ui-test',
            title: '编辑 Prompt 测试',
            systemPrompt: '回答问题。',
          ),
          aiService: service,
          sessionRepository: const _FakeChatSessionRepository(
            messages: [
              ChatMessage(fromUser: true, content: '原始 Prompt'),
              ChatMessage(fromUser: false, content: '旧回答'),
            ],
          ),
          screenTitle: '编辑 Prompt 测试',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('修改'), findsOneWidget);
    await tester.tap(find.byTooltip('修改'));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('paper-ai-input')))
          .controller
          ?.text,
      '原始 Prompt',
    );

    await tester.enterText(
      find.byKey(const ValueKey('paper-ai-input')),
      '修改后的 Prompt',
    );
    await tester.tap(find.byKey(const ValueKey('paper-ai-send')));
    await tester.pumpAndSettle();

    expect(find.text('旧回答'), findsNothing);
    expect(find.text('重新生成后的回答'), findsOneWidget);
    expect(
      service.conversations.single.where((message) => message.fromUser),
      hasLength(1),
    );
    expect(service.conversations.single.first.content, '修改后的 Prompt');
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
  testWidgets('sending a message dismisses the composer keyboard',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: PaperAiChatScreen(
          chatContext: const ChatContext(
            id: 'keyboard-dismiss-ui-test',
            title: '键盘收起测试',
            systemPrompt: '回答问题。',
          ),
          aiService: const _FakeChatAiService(),
          sessionRepository: _FakeChatSessionRepository(),
          screenTitle: '键盘收起测试',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final input = find.byKey(const ValueKey('paper-ai-input'));
    await tester.tap(input);
    await tester.pump();
    final editable = tester.widget<EditableText>(
      find.descendant(
        of: input,
        matching: find.byType(EditableText),
      ),
    );
    expect(editable.focusNode.hasFocus, isTrue, reason: '点击输入区后应获得焦点并弹出键盘');

    await tester.enterText(input, '你好');
    await tester.pump();
    expect(tester.widget<TextField>(input).controller?.text, '你好',
        reason: '发送按钮应在有输入时可点击');

    await tester.tap(find.byKey(const ValueKey('paper-ai-send')));
    await tester.pumpAndSettle();

    // 发送确实发生：输入框被清空。
    expect(tester.widget<TextField>(input).controller?.text, isEmpty,
        reason: '发送后应清空输入框');

    // 发送后应立即收起键盘，AI 回复期间不重新聚焦。
    final editableAfterSend = tester.widget<EditableText>(
      find.descendant(
        of: input,
        matching: find.byType(EditableText),
      ),
    );
    expect(editableAfterSend.focusNode.hasFocus, isFalse,
        reason: '发送后应立即收起键盘，AI 回复期间不重新聚焦');
    expect(tester.takeException(), isNull);
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

class _QueueUiChatAiService implements ChatAiService {
  _QueueUiChatAiService(this.answers);

  final List<String> answers;
  final List<List<ChatMessage>> conversations = [];

  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async {
    conversations.add(List<ChatMessage>.from(conversation));
    return answers.removeAt(0);
  }
}
