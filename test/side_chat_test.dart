import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/core/storage/local_json_store.dart';
import 'package:spark/src/features/chat/application/chat_conversation_controller.dart';
import 'package:spark/src/features/chat/application/main_ai_chat_definition.dart';
import 'package:spark/src/features/chat/application/side_chat_dismiss_preference_controller.dart';
import 'package:spark/src/features/chat/data/in_memory_chat_session_repository.dart';
import 'package:spark/src/features/chat/data/side_chat_dismiss_preference_store.dart';
import 'package:spark/src/features/chat/domain/chat_ai_service.dart';
import 'package:spark/src/features/chat/domain/chat_context.dart';
import 'package:spark/src/features/chat/domain/chat_message.dart';
import 'package:spark/src/features/chat/presentation/main_ai_chat_screen.dart';

void main() {
  testWidgets('主聊天展示 side chat 入口并可进出临时会话', (tester) async {
    final service = _FakeAiService();
    final repository = InMemoryChatSessionRepository();
    final conversation = ChatConversationController(
      context: MainAiChatDefinition.context,
      service: service,
      sessionRepository: repository,
    );
    addTearDown(conversation.dispose);
    final prefStore = _MemorySideChatPreferenceController();

    await tester.pumpWidget(
      MaterialApp(
        home: MainAiChatScreen(
          aiService: service,
          sessionRepository: repository,
          conversationController: conversation,
          sideChatPreferenceController: prefStore,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 主聊天：标题与入口可见，未进入临时态
    expect(find.text('主聊天'), findsOneWidget);
    expect(find.byKey(const ValueKey('paper-ai-side-chat-toggle')),
        findsOneWidget);
    expect(find.text('主聊天（临时聊天）'), findsNothing);

    // 进入 side chat
    await tester.tap(find.byKey(const ValueKey('paper-ai-side-chat-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('主聊天（临时聊天）'), findsOneWidget);
    expect(find.text('临时会话'), findsOneWidget);
    expect(find.byKey(const ValueKey('side-chat-screen')), findsOneWidget);

    // 退出：弹出“不会保存”提示
    await tester.tap(find.byKey(const ValueKey('paper-ai-side-chat-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('临时聊天内容不会保存。'), findsOneWidget);
    expect(find.text('不再显示'), findsOneWidget);

    // 取消：仍停留在 side chat
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('side-chat-screen')), findsOneWidget);

    // 再次退出并确认
    await tester.tap(find.byKey(const ValueKey('paper-ai-side-chat-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-exit-side-chat')));
    await tester.pumpAndSettle();

    expect(find.text('主聊天'), findsOneWidget);
    expect(find.byKey(const ValueKey('main-chat-screen')), findsOneWidget);
  });

  testWidgets('勾选不再显示后再次退出不再弹窗', (tester) async {
    final service = _FakeAiService();
    final repository = InMemoryChatSessionRepository();
    final conversation = ChatConversationController(
      context: MainAiChatDefinition.context,
      service: service,
      sessionRepository: repository,
    );
    addTearDown(conversation.dispose);
    final prefStore = _MemorySideChatPreferenceController();

    await tester.pumpWidget(
      MaterialApp(
        home: MainAiChatScreen(
          aiService: service,
          sessionRepository: repository,
          conversationController: conversation,
          sideChatPreferenceController: prefStore,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 进入 side chat
    await tester.tap(find.byKey(const ValueKey('paper-ai-side-chat-toggle')));
    await tester.pumpAndSettle();

    // 退出：勾选不再显示后确认
    await tester.tap(find.byKey(const ValueKey('paper-ai-side-chat-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirm-exit-side-chat')));
    await tester.pumpAndSettle();

    expect(prefStore.saved, isTrue);
    expect(find.byKey(const ValueKey('main-chat-screen')), findsOneWidget);

    // 再次进入并退出：不再弹窗，直接返回主聊天
    await tester.tap(find.byKey(const ValueKey('paper-ai-side-chat-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paper-ai-side-chat-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('临时聊天内容不会保存。'), findsNothing);
    expect(find.byKey(const ValueKey('main-chat-screen')), findsOneWidget);
  });

  testWidgets('side chat 消息不污染主聊天', (tester) async {
    final service = _FakeAiService();
    final repository = InMemoryChatSessionRepository();
    final conversation = ChatConversationController(
      context: MainAiChatDefinition.context,
      service: service,
      sessionRepository: repository,
    );
    addTearDown(conversation.dispose);
    // 预设主聊天已有 1 条消息
    await conversation.send('主线问题');
    await tester.pumpAndSettle();
    final beforeCount = conversation.messages.length;
    final prefStore = _MemorySideChatPreferenceController(suppress: true);

    await tester.pumpWidget(
      MaterialApp(
        home: MainAiChatScreen(
          aiService: service,
          sessionRepository: repository,
          conversationController: conversation,
          sideChatPreferenceController: prefStore,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 进入 side chat 并发送临时消息
    await tester.tap(find.byKey(const ValueKey('paper-ai-side-chat-toggle')));
    await tester.pumpAndSettle();

    // 在临时会话中发送
    await tester.enterText(find.byType(TextField).last, '临时追问什么是注意力？');
    await tester.tap(find.byKey(const ValueKey('paper-ai-send')));
    await tester.pumpAndSettle();

    // 主聊天消息数未变（临时消息不写入主会话）
    expect(conversation.messages.length, beforeCount);

    // 退出 side chat（已 suppress，不弹窗）
    await tester.tap(find.byKey(const ValueKey('paper-ai-side-chat-toggle')));
    await tester.pumpAndSettle();

    expect(conversation.messages.length, beforeCount);
    expect(find.byKey(const ValueKey('main-chat-screen')), findsOneWidget);
  });

  test('SideChatDismissPreferenceStore 读写', () async {
    final dir = await Directory.systemTemp.createTemp('spark_side_chat_test_');
    addTearDown(() async {
      try {
        await dir.delete(recursive: true);
      } catch (error) {
        // 临时目录清理失败可忽略，不影响断言结果。
      }
    });
    final store = SideChatDismissPreferenceStore(
      store: LocalJsonStore(
        file: File('${dir.path}/side_chat_preferences.json'),
        fileName: 'side_chat_preferences.json',
      ),
    );
    expect(await store.load(), isFalse);
    await store.save(true);
    expect(await store.load(), isTrue);
    await store.save(false);
    expect(await store.load(), isFalse);
  });
}

class _FakeAiService implements ChatAiService {
  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async =>
      'fake-answer';
}

class _MemorySideChatPreferenceController
    implements SideChatDismissPreferenceController {
  _MemorySideChatPreferenceController({bool suppress = false})
      : _suppress = suppress;

  bool _suppress;
  bool saved = false;

  @override
  Future<bool> load() async => _suppress;

  @override
  Future<void> save(bool suppress) async {
    _suppress = suppress;
    saved = suppress;
  }
}
