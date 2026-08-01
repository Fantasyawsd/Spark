import 'dart:io';

import 'package:flutter/services.dart';

import '../application/paper_share_service.dart';

class PlatformPaperShareService implements PaperShareService {
  const PlatformPaperShareService();

  static const _channel = MethodChannel('paperflow/share');

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
      await Clipboard.setData(ClipboardData(text: payload.text));
      return PaperShareResult.copied;
    } on PlatformException catch (error) {
      throw PaperShareException('无法打开系统分享面板。', error);
    }
  }
}
