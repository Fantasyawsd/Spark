import 'package:flutter/material.dart';

import '../application/chat_ai_service.dart';
import '../application/main_ai_chat_definition.dart';
import '../domain/chat_session_repository.dart';
import '../domain/chat_session_settings.dart';
import 'paper_ai_chat_screen.dart';

class MainAiChatScreen extends StatelessWidget {
  const MainAiChatScreen({
    super.key,
    required this.aiService,
    this.webSearchAiService,
    required this.sessionRepository,
    this.settingsRepository,
  });

  final ChatAiService aiService;
  final ChatAiService? webSearchAiService;
  final ChatSessionRepository sessionRepository;
  final ChatSessionSettingsRepository? settingsRepository;

  @override
  Widget build(BuildContext context) {
    return PaperAiChatScreen(
      chatContext: MainAiChatDefinition.context,
      aiService: aiService,
      webSearchAiService: webSearchAiService,
      sessionRepository: sessionRepository,
      settingsRepository: settingsRepository,
      screenTitle: '主聊天',
      screenSubtitle: '主会话',
      welcomeTitle: '今天想研究什么？',
      welcomeDescription: '跨论文提问、整理研究思路，或联网检索最新资料',
      clearConfirmation: '这会删除主聊天中的全部 AI 对话记录。',
    );
  }
}
