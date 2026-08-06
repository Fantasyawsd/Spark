import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/src/features/chat/application/chat_ai_service.dart';
import 'package:paperflow/src/features/chat/application/chat_conversation_controller.dart';
import 'package:paperflow/src/features/chat/application/chat_prompt_assembler.dart';
import 'package:paperflow/src/features/chat/application/chat_skills.dart';
import 'package:paperflow/src/features/chat/data/in_memory_chat_session_settings_repository.dart';
import 'package:paperflow/src/features/chat/domain/chat_context.dart';
import 'package:paperflow/src/features/chat/domain/chat_session_settings.dart';
import 'package:paperflow/src/features/chat/domain/chat_message.dart';

void main() {
  const context = ChatContext(
    id: 'settings-test',
    title: '设置测试',
    systemPrompt: '默认提示词',
    webSearchSystemPrompt: '联网默认提示词',
  );

  group('ChatPromptAssembler', () {
    test('keeps the default prompt when no customization exists', () {
      final result =
          ChatPromptAssembler.applySettings(context, ChatSessionSettings.empty);
      expect(result.systemPrompt, '默认提示词');
      expect(result.promptFor(webSearch: true), '联网默认提示词');
    });

    test('custom system prompt replaces the default prompt', () {
      final result = ChatPromptAssembler.applySettings(
        context,
        const ChatSessionSettings(customSystemPrompt: '自定义提示词'),
      );
      expect(result.systemPrompt, contains('自定义提示词'));
      expect(result.systemPrompt, isNot(contains('默认提示词')));
    });

    test('response style and enabled skills are appended', () {
      final result = ChatPromptAssembler.applySettings(
        context,
        const ChatSessionSettings(
          responseStyle: ChatResponseStyle.concise,
          enabledSkillIds: ['rigorous-citation', 'math-derivation'],
        ),
      );
      expect(
          result.systemPrompt, contains(ChatResponseStyle.concise.instruction));
      expect(result.systemPrompt,
          contains(ChatSkills.byId('rigorous-citation')!.prompt));
      expect(result.systemPrompt,
          contains(ChatSkills.byId('math-derivation')!.prompt));
    });

    test('web search prompt receives the same customizations', () {
      final result = ChatPromptAssembler.applySettings(
        context,
        const ChatSessionSettings(
          customSystemPrompt: '统一提示词',
          enabledSkillIds: ['code-assist'],
        ),
      );
      expect(result.promptFor(webSearch: true), contains('统一提示词'));
      expect(
        result.promptFor(webSearch: true),
        contains(ChatSkills.byId('code-assist')!.prompt),
      );
    });
  });

  group('ChatConversationController settings', () {
    test('loads persisted settings and uses them for the request', () async {
      final repository = InMemoryChatSessionSettingsRepository();
      await repository.save(
        context.id,
        const ChatSessionSettings(customSystemPrompt: '持久化提示词'),
      );
      final service = _CapturingChatAiService();
      final controller = ChatConversationController(
        context: context,
        service: service,
        settingsRepository: repository,
      );
      await controller.initialize();

      expect(controller.settings.customSystemPrompt, '持久化提示词');
      await controller.send('问题');
      expect(service.context?.systemPrompt, contains('持久化提示词'));
      expect(service.context?.systemPrompt, isNot(contains('默认提示词')));
      controller.dispose();
    });

    test('updateSettings persists and applies immediately', () async {
      final repository = InMemoryChatSessionSettingsRepository();
      final service = _CapturingChatAiService();
      final controller = ChatConversationController(
        context: context,
        service: service,
        settingsRepository: repository,
      );

      await controller.updateSettings(
        const ChatSessionSettings(
          responseStyle: ChatResponseStyle.detailed,
          enabledSkillIds: ['paper-critique'],
        ),
      );
      await controller.send('问题');

      expect(controller.settings.responseStyle, ChatResponseStyle.detailed);
      expect(service.context?.systemPrompt, contains('详细'));
      expect(
        service.context?.systemPrompt,
        contains(ChatSkills.byId('paper-critique')!.prompt),
      );
      final reloaded = await repository.load(context.id);
      expect(reloaded.responseStyle, ChatResponseStyle.detailed);
      controller.dispose();
    });
  });
}

class _CapturingChatAiService
    implements ChatAiService, StreamingChatAiService, CancellableChatAiService {
  ChatContext? context;
  List<ChatMessage> conversation = [];

  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async {
    this.context = context;
    this.conversation = List<ChatMessage>.from(conversation);
    return '通用回答';
  }

  @override
  Stream<ChatStreamChunk> answerStream({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async* {
    this.context = context;
    this.conversation = List<ChatMessage>.from(conversation);
    yield const ChatStreamChunk(contentDelta: '通用回答');
  }

  @override
  void cancelActiveRequest() {}
}
