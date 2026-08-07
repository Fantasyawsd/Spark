import 'package:flutter/services.dart';

abstract interface class SparkClipboard {
  Future<void> copyText(String text);
}

final class PlatformSparkClipboard implements SparkClipboard {
  const PlatformSparkClipboard();

  @override
  Future<void> copyText(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }
}

const SparkClipboard platformSparkClipboard = PlatformSparkClipboard();
