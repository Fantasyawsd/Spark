import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/chat/domain/chat_ai_service.dart';
import 'package:spark/src/features/chat/domain/chat_context.dart';
import 'package:spark/src/features/chat/domain/chat_message.dart';
import 'package:spark/src/features/chat/domain/chat_session_repository.dart';
import 'package:spark/src/features/chat/presentation/paper_ai_chat_screen.dart';

void main() {
  testWidgets('desktop keeps composer focused after sending', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('paper-ai-input')),
      '桌面连续输入',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('paper-ai-send')));
    await tester.pumpAndSettle();

    expect(_composerFocusNode(tester).hasFocus, isTrue);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('android dismisses composer focus after sending', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('paper-ai-input')),
      '移动端发送收键盘',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('paper-ai-send')));
    await tester.pumpAndSettle();

    expect(_composerFocusNode(tester).hasFocus, isFalse);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('selection mode keeps no focus and exiting does not pop keyboard',
      (tester) async {
    await tester.pumpWidget(
      _buildScreen(
        messages: const [ChatMessage(fromUser: false, content: '历史回答')],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('paper-ai-input')));
    await tester.pump();
    final composerNode = _composerFocusNode(tester);
    expect(composerNode.hasFocus, isTrue);

    await tester.tap(find.byKey(const ValueKey('paper-ai-assistant-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除消息'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('paper-ai-selection-bar')),
      findsOneWidget,
    );
    expect(FocusManager.instance.primaryFocus, isNot(same(composerNode)));
    expect(composerNode.hasFocus, isFalse);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('paper-ai-input')), findsOneWidget);
    expect(_composerFocusNode(tester).hasFocus, isFalse);
  });
}

Widget _buildScreen({List<ChatMessage> messages = const []}) {
  return MaterialApp(
    home: PaperAiChatScreen(
      chatContext: const ChatContext(
        id: 'keyboard-interactions-test',
        title: '键盘交互测试',
        systemPrompt: '回答问题。',
      ),
      aiService: const _FakeChatAiService(),
      sessionRepository: _FakeChatSessionRepository(messages: messages),
      screenTitle: '键盘交互测试',
    ),
  );
}

FocusNode _composerFocusNode(WidgetTester tester) {
  final field = tester.widget<TextField>(
    find.byKey(const ValueKey('paper-ai-input')),
  );
  return field.focusNode!;
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
