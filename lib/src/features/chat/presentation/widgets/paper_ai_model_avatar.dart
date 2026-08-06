import 'package:flutter/material.dart';

import '../paper_ai_ui_tokens.dart';

/// Shared model avatar used by the message header and Composer model selector.
///
/// The avatar has a transparent background: the network image (when loaded) is
/// the only visual, and the built-in icon is used as a fallback while loading
/// or when the network image fails.
class PaperAiModelAvatar extends StatelessWidget {
  const PaperAiModelAvatar({
    super.key,
    this.size = 34,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
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
