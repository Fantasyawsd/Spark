import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract interface class PaperAiKeyboardDismissal {
  void dismiss(FocusNode composerFocusNode);
}

class PlatformPaperAiKeyboardDismissal implements PaperAiKeyboardDismissal {
  const PlatformPaperAiKeyboardDismissal();

  @override
  void dismiss(FocusNode composerFocusNode) {
    composerFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    // Android 上焦点转移后系统输入法偶发残留，兜底显式关闭；
    // 无平台通道的环境（如测试）由 ignore 吞掉错误。
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide').ignore();
  }
}

const platformPaperAiKeyboardDismissal = PlatformPaperAiKeyboardDismissal();
