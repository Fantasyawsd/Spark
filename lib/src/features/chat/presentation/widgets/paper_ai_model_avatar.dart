import 'package:flutter/material.dart';

import '../paper_ai_ui_tokens.dart';

/// Shared model avatar used by the message header and Composer model selector.
class PaperAiModelAvatar extends StatelessWidget {
  const PaperAiModelAvatar({
    super.key,
    this.size = 34,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: PaperAiUiTokens.assistantAvatar,
        boxShadow: [
          BoxShadow(
            color: PaperAiUiTokens.modelBlue.withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Icon(
                Icons.auto_awesome_rounded,
                size: size * 0.5,
                color: PaperAiUiTokens.modelBlue,
              ),
            ),
            Image.network(
              'https://www.deepseek.com/favicon.ico',
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : const SizedBox.shrink(),
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
