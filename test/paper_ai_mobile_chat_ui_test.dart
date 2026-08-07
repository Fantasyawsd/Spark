import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/core/theme/spark_theme_color.dart';
import 'package:spark/src/core/theme/spark_theme.dart';
import 'package:spark/src/core/theme/theme_controller.dart';
import 'package:spark/src/features/chat/domain/chat_ai_service.dart';
import 'package:spark/src/features/chat/domain/chat_context.dart';
import 'package:spark/src/features/chat/domain/chat_message.dart';
import 'package:spark/src/features/chat/domain/chat_session_repository.dart';
import 'package:spark/src/features/chat/data/in_memory_chat_session_settings_repository.dart';
import 'package:spark/src/features/chat/presentation/paper_ai_chat_screen.dart';

void main() {
  testWidgets('mobile chat colors follow the active Material theme',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(
      () => ThemeController.instance.setColor(SparkThemeColor.pink),
    );

    const messages = [
      ChatMessage(fromUser: true, content: '主题问题'),
      ChatMessage(
        fromUser: false,
        content: '主题回答',
        reasoningContent: '主题推理',
      ),
    ];
    ThemeController.instance.setColor(SparkThemeColor.blue);
    final blueTheme = SparkTheme.light();
    ThemeController.instance.setColor(SparkThemeColor.green);
    final greenTheme = SparkTheme.light();

    Future<_ChatThemeColors> pumpWithTheme(ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: PaperAiChatScreen(
            chatContext: const ChatContext(
              id: 'theme-ui-test',
              title: '主题测试',
              systemPrompt: '回答问题。',
            ),
            aiService: const _FakeChatAiService(),
            sessionRepository:
                const _FakeChatSessionRepository(messages: messages),
            screenTitle: '主题测试',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('paper-ai-input')),
        '启用发送按钮',
      );
      await tester.pump();
      return _readChatThemeColors(tester);
    }

    final blueColors = await pumpWithTheme(blueTheme);
    expect(blueColors.canvas, _accentBlend(blueTheme, 0.02));
    expect(blueColors.userBubble, blueTheme.colorScheme.primaryContainer);
    expect(blueColors.composer, _accentBlend(blueTheme, 0.06));
    expect(blueColors.reasoning, _accentBlend(blueTheme, 0.08));
    expect(blueColors.activeControl, blueTheme.colorScheme.primary);

    final greenColors = await pumpWithTheme(greenTheme);
    expect(greenColors.canvas, _accentBlend(greenTheme, 0.02));
    expect(greenColors.userBubble, greenTheme.colorScheme.primaryContainer);
    expect(greenColors.composer, _accentBlend(greenTheme, 0.06));
    expect(greenColors.reasoning, _accentBlend(greenTheme, 0.08));
    expect(greenColors.activeControl, greenTheme.colorScheme.primary);
    expect(greenColors.canvas, isNot(blueColors.canvas));
    expect(greenColors.userBubble, isNot(blueColors.userBubble));
    expect(greenColors.composer, isNot(blueColors.composer));
    expect(greenColors.reasoning, isNot(blueColors.reasoning));
    expect(greenColors.activeControl, isNot(blueColors.activeControl));
  });

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

  testWidgets('session settings customize the system prompt for the request',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final service = _CapturingUiChatAiService();
    await tester.pumpWidget(
      MaterialApp(
        home: PaperAiChatScreen(
          chatContext: const ChatContext(
            id: 'settings-ui-test',
            title: '设置 UI 测试',
            systemPrompt: '默认提示词',
          ),
          aiService: service,
          sessionRepository: _FakeChatSessionRepository(),
          settingsRepository: InMemoryChatSessionSettingsRepository(),
          screenTitle: '设置 UI 测试',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('paper-ai-session-settings')));
    await tester.pumpAndSettle();
    expect(find.text('会话设置'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('paper-ai-settings-prompt')),
      '始终用中文回答',
    );
    await tester.tap(find.byKey(const ValueKey('paper-ai-settings-save')));
    await tester.pumpAndSettle();
    expect(find.text('会话设置'), findsNothing);

    final input = find.byKey(const ValueKey('paper-ai-input'));
    await tester.enterText(input, '你好');
    await tester.pump();
    expect(
      tester.widget<TextField>(input).controller?.text,
      '你好',
      reason: '发送前输入框应有内容',
    );

    await tester.tap(find.byKey(const ValueKey('paper-ai-send')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(input).controller?.text,
      isEmpty,
      reason: '发送后输入框应被清空',
    );

    expect(service.context, isNotNull, reason: 'AI 服务应收到请求');
    expect(service.context?.systemPrompt, contains('始终用中文回答'));
    expect(service.context?.systemPrompt, isNot(contains('默认提示词')));
    expect(tester.takeException(), isNull);
  });
  testWidgets('full text toggle loads and injects the paper PDF context',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final service = _CapturingUiChatAiService();
    await tester.pumpWidget(
      MaterialApp(
        home: PaperAiChatScreen(
          chatContext: const ChatContext(
            id: 'fulltext-ui-test',
            title: '全文测试',
            systemPrompt: '默认提示词',
          ),
          aiService: service,
          sessionRepository: _FakeChatSessionRepository(),
          fullTextAvailable: true,
          onLoadFullText: () async => const ChatContext(
            id: 'fulltext-ui-test',
            title: '全文测试',
            systemPrompt: '默认提示词 + 论文全文引用',
          ),
          screenTitle: '全文测试',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('paper-ai-fulltext-toggle')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('paper-ai-fulltext-toggle')));
    await tester.pumpAndSettle();

    final input = find.byKey(const ValueKey('paper-ai-input'));
    await tester.enterText(input, '你好');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('paper-ai-send')));
    await tester.pumpAndSettle();

    expect(service.context?.systemPrompt, contains('论文全文引用'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('full text context mismatch leaves the action retryable',
      (tester) async {
    var loadCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PaperAiChatScreen(
          chatContext: const ChatContext(
            id: 'current-paper',
            title: '当前论文',
            systemPrompt: '默认提示词',
          ),
          aiService: const _FakeChatAiService(),
          sessionRepository: const _FakeChatSessionRepository(),
          fullTextAvailable: true,
          onLoadFullText: () async {
            loadCalls++;
            return const ChatContext(
              id: 'another-paper',
              title: '其他论文',
              systemPrompt: '不应注入的全文',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toggle = find.byKey(const ValueKey('paper-ai-fulltext-toggle'));
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.widget<IconButton>(toggle).onPressed, isNotNull);
    expect(find.text('全文上下文与当前会话不匹配，请重试。'), findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(loadCalls, 2);
  });

  testWidgets('full text loader errors reset the action and show feedback',
      (tester) async {
    var loadCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PaperAiChatScreen(
          chatContext: const ChatContext(
            id: 'error-paper',
            title: '错误论文',
            systemPrompt: '默认提示词',
          ),
          aiService: const _FakeChatAiService(),
          sessionRepository: const _FakeChatSessionRepository(),
          fullTextAvailable: true,
          onLoadFullText: () async {
            loadCalls++;
            throw ArgumentError('simulated parser failure');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toggle = find.byKey(const ValueKey('paper-ai-fulltext-toggle'));
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.widget<IconButton>(toggle).onPressed, isNotNull);
    expect(find.text('无法读取论文全文，请稍后重试。'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(loadCalls, 2);
  });
}

Color _accentBlend(ThemeData theme, double opacity) {
  return Color.alphaBlend(
    theme.colorScheme.primary.withValues(alpha: opacity),
    theme.colorScheme.surface,
  );
}

_ChatThemeColors _readChatThemeColors(WidgetTester tester) {
  Color decorationColor(String key) {
    final container = tester.widget<Container>(
      find.byKey(ValueKey(key)),
    );
    return (container.decoration! as BoxDecoration).color!;
  }

  final sendButton = tester.widget<IconButton>(
    find.byKey(const ValueKey('paper-ai-send')),
  );
  return _ChatThemeColors(
    canvas: tester
        .widget<Scaffold>(
          find.byKey(const ValueKey('paper-ai-chat-screen')),
        )
        .backgroundColor!,
    userBubble: decorationColor('paper-ai-user-bubble'),
    composer: decorationColor('paper-ai-composer-surface'),
    reasoning: decorationColor('paper-ai-reasoning-surface'),
    activeControl: sendButton.style!.backgroundColor!.resolve({})!,
  );
}

class _ChatThemeColors {
  const _ChatThemeColors({
    required this.canvas,
    required this.userBubble,
    required this.composer,
    required this.reasoning,
    required this.activeControl,
  });

  final Color canvas;
  final Color userBubble;
  final Color composer;
  final Color reasoning;
  final Color activeControl;
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

class _CapturingUiChatAiService implements ChatAiService {
  ChatContext? context;

  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async {
    this.context = context;
    return '回答';
  }
}
