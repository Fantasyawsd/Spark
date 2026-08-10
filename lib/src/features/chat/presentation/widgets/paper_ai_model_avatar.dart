import 'package:flutter/material.dart';

import '../paper_ai_ui_tokens.dart';

/// Shared model avatar used by the message header and Composer model selector.
///
/// Local-only visual: the bundled DeepSeek mark on a tinted circle. No network
/// dependency, so it renders identically offline and online. The mark is
/// extracted from the provider's published favicon and identifies the model
/// provider for BYOK chats.
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
        color: PaperAiUiTokens.userBubble(context),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(size * 0.16),
          child: Image.asset(
            'assets/images/deepseek_logo.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
