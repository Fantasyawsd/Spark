import 'dart:io';

import 'package:flutter/services.dart';

import '../../../core/platform/spark_clipboard.dart';
import '../domain/paper_share.dart';

class PlatformPaperShareService implements PaperShareService {
  const PlatformPaperShareService({
    this.clipboard = platformSparkClipboard,
  });

  static const _channel = MethodChannel('spark/share');
  final SparkClipboard clipboard;

  @override
  Future<PaperShareResult> share(PaperSharePayload payload) async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod<void>('shareText', {
          'subject': payload.subject,
          'text': payload.text,
        });
        return PaperShareResult.shared;
      }
      await clipboard.copyText(payload.text);
      return PaperShareResult.copied;
    } catch (error) {
      throw PaperShareException('无法打开系统分享面板。', error);
    }
  }
}
