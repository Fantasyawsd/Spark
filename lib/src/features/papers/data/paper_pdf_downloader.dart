import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../domain/paper_pdf.dart';

const paperPdfDownloaderDefaultMaxDownloadBytes = 32 * 1024 * 1024;

/// Downloads and validates a PDF without knowing how its contents are parsed.
class PaperPdfDownloader {
  PaperPdfDownloader({
    http.Client? client,
    this.maxDownloadBytes = paperPdfDownloaderDefaultMaxDownloadBytes,
    this.downloadTimeout = const Duration(seconds: 60),
  }) : _injectedClient = client;

  final http.Client? _injectedClient;
  final int maxDownloadBytes;
  final Duration downloadTimeout;

  Future<List<int>> download(Uri url) async {
    if (maxDownloadBytes <= 0 || downloadTimeout <= Duration.zero) {
      throw const PaperPdfException('PDF 下载限制配置无效。');
    }
    final client = _injectedClient ?? http.Client();
    final elapsed = Stopwatch()..start();
    try {
      final response =
          await client.send(http.Request('GET', url)).timeout(downloadTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await _cancelResponseBody(response);
        throw PaperPdfException('PDF 下载失败（HTTP ${response.statusCode}）。');
      }
      final declaredLength = response.contentLength;
      if (declaredLength != null && declaredLength > maxDownloadBytes) {
        await _cancelResponseBody(response);
        throw const PaperPdfException('PDF 文件过大，无法在设备上安全处理。');
      }
      final remaining = downloadTimeout - elapsed.elapsed;
      if (remaining <= Duration.zero) {
        await _cancelResponseBody(response);
        throw TimeoutException('PDF download timed out.', downloadTimeout);
      }
      final result = await _readResponseBody(response, timeout: remaining);
      if (!looksLikePaperPdf(result)) {
        throw const PaperPdfException('下载的内容不是有效的 PDF。');
      }
      return result;
    } on PaperPdfException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        const PaperPdfException('无法下载 PDF，请检查网络后重试。'),
        stackTrace,
      );
    } finally {
      if (_injectedClient == null) client.close();
    }
  }

  static Future<void> _cancelResponseBody(http.StreamedResponse response) {
    return response.stream.listen(null).cancel();
  }

  Future<Uint8List> _readResponseBody(
    http.StreamedResponse response, {
    required Duration timeout,
  }) {
    final completer = Completer<Uint8List>();
    final bytes = BytesBuilder(copy: false);
    StreamSubscription<List<int>>? subscription;
    Timer? deadline;
    var receivedBytes = 0;
    var settled = false;

    void fail(Object error, StackTrace stackTrace) {
      if (settled) return;
      settled = true;
      deadline?.cancel();
      completer.completeError(error, stackTrace);
      final cancellation = subscription?.cancel();
      if (cancellation != null) unawaited(cancellation);
    }

    subscription = response.stream.listen(
      (chunk) {
        if (settled) return;
        receivedBytes += chunk.length;
        if (receivedBytes > maxDownloadBytes) {
          fail(
            const PaperPdfException('PDF 文件过大，无法在设备上安全处理。'),
            StackTrace.current,
          );
          return;
        }
        bytes.add(chunk);
      },
      onError: (Object error, StackTrace stackTrace) {
        fail(error, stackTrace);
      },
      onDone: () {
        if (settled) return;
        settled = true;
        deadline?.cancel();
        completer.complete(bytes.takeBytes());
      },
    );
    if (settled) {
      unawaited(subscription.cancel());
    } else {
      deadline = Timer(
        timeout,
        () => fail(
          TimeoutException('PDF download timed out.', downloadTimeout),
          StackTrace.current,
        ),
      );
    }
    return completer.future;
  }
}

bool looksLikePaperPdf(List<int> bytes) {
  if (bytes.length < 5) return false;
  return bytes[0] == 0x25 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x44 &&
      bytes[3] == 0x46;
}
