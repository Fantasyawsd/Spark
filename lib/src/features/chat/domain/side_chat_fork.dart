import 'chat_context.dart';
import 'chat_message.dart';

/// 从主聊天状态 fork 临时 side chat 上下文。
///
/// - 只读快照主聊天的 [ChatContext.systemPrompt] 与消息历史；
/// - 产出仅内存存在的临时 [ChatContext]，不复用持久化 id；
/// - 消息历史以背景段落注入 system prompt，不作为聊天消息写入。
abstract final class SideChatFork {
  static const String sideChatId = 'spark-main-ai-chat__side';

  static const String _backgroundHeader =
      '\n\n---\n以下是主聊天的背景信息（只读参考，不要复述为消息历史）：';

  /// 创建 side chat 临时上下文。
  ///
  /// [mainContext] 为主聊天的 effectiveContext（已应用会话设置）；
  /// [messages] 为主聊天当前消息快照。
  static ChatContext create({
    required ChatContext mainContext,
    required List<ChatMessage> messages,
  }) {
    final background = _buildBackground(messages);
    final systemPrompt = background.isEmpty
        ? mainContext.systemPrompt
        : '${mainContext.systemPrompt}$_backgroundHeader\n$background';
    final webSearchPrompt = mainContext.webSearchSystemPrompt == null
        ? null
        : background.isEmpty
            ? mainContext.webSearchSystemPrompt
            : '${mainContext.webSearchSystemPrompt}$_backgroundHeader\n$background';

    return ChatContext(
      id: sideChatId,
      title: '${mainContext.title}（临时聊天）',
      subtitle: '临时会话 · 退出不保存',
      systemPrompt: systemPrompt,
      webSearchSystemPrompt: webSearchPrompt,
    );
  }

  static String _buildBackground(List<ChatMessage> messages) {
    if (messages.isEmpty) return '';
    final buffer = StringBuffer();
    for (final message in messages) {
      final role = message.fromUser ? '用户' : '助手';
      final content = message.content.trim();
      if (content.isEmpty) continue;
      // 截断过长单条，避免 prompt 爆炸。
      final clipped =
          content.length > 800 ? '${content.substring(0, 800)}…' : content;
      buffer.writeln('[$role] $clipped');
    }
    final result = buffer.toString().trim();
    // 整体再做一次长度保护。
    if (result.length > 6000) return '${result.substring(0, 6000)}…';
    return result;
  }
}
