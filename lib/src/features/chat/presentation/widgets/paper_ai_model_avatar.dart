import 'package:flutter/material.dart';

/// Shared model avatar used by the message header and Composer model selector.
///
/// Local-only visual: the bundled DeepSeek mark with a transparent background,
/// no tinted circle. No network dependency, so it renders identically offline
/// and online. The mark is extracted from the provider's published favicon and
/// identifies the model provider for BYOK chats.
class PaperAiModelAvatar extends StatelessWidget {
  const PaperAiModelAvatar({
    super.key,
    this.size = 34,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/deepseek_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}
