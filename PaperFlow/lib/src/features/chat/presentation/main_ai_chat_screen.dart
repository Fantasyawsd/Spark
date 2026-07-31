import 'package:flutter/material.dart';

import '../../papers/application/paper_ai_service.dart';
import '../../papers/application/paper_ai_session_repository.dart';
import '../application/main_ai_chat_definition.dart';
import 'paper_ai_chat_screen.dart';

class MainAiChatScreen extends StatelessWidget {
  const MainAiChatScreen({
    super.key,
    required this.aiService,
    this.webSearchAiService,
    required this.sessionRepository,
  });

  final PaperAiService aiService;
  final PaperAiService? webSearchAiService;
  final PaperAiSessionRepository sessionRepository;

  @override
  Widget build(BuildContext context) {
    return PaperAiChatScreen(
      paper: MainAiChatDefinition.contextRecord,
      aiService: aiService,
      webSearchAiService: webSearchAiService,
      sessionRepository: sessionRepository,
      screenTitle: '主聊天',
      screenSubtitle: 'PaperFlow AI',
      welcomeTitle: '今天想研究什么？',
      welcomeDescription: '跨论文提问、整理研究思路，或联网检索最新资料',
      suggestedPrompts: const [
        '帮我梳理一个研究方向',
        '比较两篇论文的方法',
        '搜索近期相关工作',
      ],
      clearConfirmation: '这会删除主聊天中的全部 AI 对话记录。',
    );
  }
}
