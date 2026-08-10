import 'package:flutter/material.dart';

import '../paper_ai_ui_tokens.dart';

/// Shared model avatar used by the message header and Composer model selector.
///
/// Local-only visual: a tinted circle with the built-in spark icon. No network
/// dependency, so it renders identically offline and online.
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
        child: Icon(
          Icons.auto_awesome_rounded,
          size: size * 0.5,
          color: PaperAiUiTokens.accent(context),
        ),
      ),
    );
  }
}
