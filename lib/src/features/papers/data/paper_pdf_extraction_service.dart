import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../domain/paper_pdf.dart';

const paperPdfExtractionVersion = 2;
const paperPdfDefaultTargetCharsPerChunk = 1800;
const paperPdfDefaultMaxDownloadBytes = 32 * 1024 * 1024;
const paperPdfDefaultMaxInputBytes = paperPdfDefaultMaxDownloadBytes;
const paperPdfDefaultMaxPages = 300;
const paperPdfDefaultMaxExtractedChars = 1000000;
const paperPdfDefaultMaxChunks = 1024;
const paperPdfDefaultExtractionTimeout = Duration(seconds: 30);

const _paperPdfWorkerSuccess = 0;
const _paperPdfWorkerFailure = 1;

String paperPdfCacheVersion(
  Uri url, {
  DateTime? sourceUpdatedAt,
  int targetCharsPerChunk = paperPdfDefaultTargetCharsPerChunk,
}) {
  if (targetCharsPerChunk <= 0) {
    throw ArgumentError.value(
      targetCharsPerChunk,
      'targetCharsPerChunk',
      'must be positive',
    );
  }
  final revision = sourceUpdatedAt?.toUtc().toIso8601String() ?? 'unknown';
  return 'url=${url.normalizePath().removeFragment()}'
      '|sourceUpdatedAt=$revision'
      '|extractor=$paperPdfExtractionVersion'
      '|chunk=$targetCharsPerChunk';
}

/// 论文 PDF 的下载、文本提取与分块服务。
///
/// 遵循「DeepSeek 不直接上传 PDF」约束：客户端先提取文本，再按块注入
/// 上下文。提取结果由调用方通过 [PaperPdfRepository] 缓存。
class PaperPdfExtractionService {
  PaperPdfExtractionService({
    http.Client? client,
    this.maxDownloadBytes = paperPdfDefaultMaxDownloadBytes,
    this.downloadTimeout = const Duration(seconds: 60),
    this.maxInputBytes = paperPdfDefaultMaxInputBytes,
    this.maxPages = paperPdfDefaultMaxPages,
    this.maxExtractedChars = paperPdfDefaultMaxExtractedChars,
    this.maxChunks = paperPdfDefaultMaxChunks,
    this.extractionTimeout = paperPdfDefaultExtractionTimeout,
  }) : _injectedClient = client;

  final http.Client? _injectedClient;
  final int maxDownloadBytes;
  final Duration downloadTimeout;
  final int maxInputBytes;
  final int maxPages;
  final int maxExtractedChars;
  final int maxChunks;
  final Duration extractionTimeout;

  /// 下载 PDF 字节；非 2xx 或内容不是 PDF 时抛出 [PaperPdfException]。
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
      if (!_looksLikePdf(result)) {
        throw const PaperPdfException('下载的内容不是有效的 PDF。');
      }
      return result;
    } on PaperPdfException {
      rethrow;
    } catch (_) {
      throw const PaperPdfException('无法下载 PDF，请检查网络后重试。');
    } finally {
      if (_injectedClient == null) client.close();
    }
  }

  /// 从 PDF 字节提取文本并按目标长度分块。
  Future<PaperPdfExtract> extract({
    required String paperId,
    required String version,
    required List<int> bytes,
    int targetCharsPerChunk = paperPdfDefaultTargetCharsPerChunk,
  }) {
    _validateExtractionLimits();
    if (targetCharsPerChunk <= 0) {
      throw const PaperPdfException('PDF 分块长度必须大于 0。');
    }
    if (bytes.length > maxInputBytes) {
      throw const PaperPdfException('PDF 文件过大，无法在设备上安全解析。');
    }
    if (!_looksLikePdf(bytes)) {
      throw const PaperPdfException('不是有效的 PDF 文件。');
    }
    final typedBytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final transferable = TransferableTypedData.fromList([
      typedBytes,
    ]);
    return _runExtractionWorker(
      _PaperPdfWorkerRequest(
        paperId: paperId,
        version: version,
        bytes: transferable,
        targetCharsPerChunk: targetCharsPerChunk,
        maxPages: maxPages,
        maxExtractedChars: maxExtractedChars,
        maxChunks: maxChunks,
      ),
    );
  }

  void _validateExtractionLimits() {
    if (maxInputBytes <= 0 ||
        maxPages <= 0 ||
        maxExtractedChars <= 0 ||
        maxChunks <= 0 ||
        extractionTimeout <= Duration.zero) {
      throw const PaperPdfException('PDF 解析限制配置无效。');
    }
  }

  Future<PaperPdfExtract> _runExtractionWorker(
    _PaperPdfWorkerRequest request,
  ) {
    final resultPort = ReceivePort();
    final errorPort = ReceivePort();
    final completer = Completer<PaperPdfExtract>();
    Isolate? worker;
    Timer? deadline;
    var settled = false;

    void releaseResources() {
      deadline?.cancel();
      resultPort.close();
      errorPort.close();
      worker?.kill(priority: Isolate.immediate);
    }

    void completeWithError(PaperPdfException error, StackTrace stackTrace) {
      if (settled) return;
      settled = true;
      releaseResources();
      completer.completeError(error, stackTrace);
    }

    void completeWithResult(PaperPdfExtract result) {
      if (settled) return;
      settled = true;
      releaseResources();
      completer.complete(result);
    }

    resultPort.listen((message) {
      if (message is! List || message.isEmpty) {
        completeWithError(
          const PaperPdfException('PDF 解析 worker 返回了无效结果。'),
          StackTrace.current,
        );
        return;
      }
      switch (message[0]) {
        case _paperPdfWorkerSuccess:
          final result = message.length > 1 ? message[1] : null;
          if (result is PaperPdfExtract) {
            completeWithResult(result);
            return;
          }
          break;
        case _paperPdfWorkerFailure:
          final errorMessage = message.length > 1 ? message[1] : null;
          final stack = message.length > 2 ? message[2] : null;
          if (errorMessage is String) {
            completeWithError(
              PaperPdfException(errorMessage),
              StackTrace.fromString(stack is String ? stack : ''),
            );
            return;
          }
          break;
      }
      completeWithError(
        const PaperPdfException('PDF 解析 worker 返回了无效结果。'),
        StackTrace.current,
      );
    });
    errorPort.listen((message) {
      final stack = message is List && message.length > 1 ? message[1] : null;
      completeWithError(
        const PaperPdfException('PDF 解析失败，文件可能已损坏。'),
        StackTrace.fromString(stack is String ? stack : ''),
      );
    });
    deadline = Timer(
      extractionTimeout,
      () => completeWithError(
        const PaperPdfException('PDF 解析超时，请尝试较小的文件。'),
        StackTrace.current,
      ),
    );

    final spawn = Isolate.spawn<_PaperPdfWorkerRequest>(
      _extractPaperPdfInWorker,
      request.withResultPort(resultPort.sendPort),
      debugName: 'paper-pdf-extraction',
      errorsAreFatal: true,
      onError: errorPort.sendPort,
    );
    unawaited(
      spawn.then(
        (spawned) {
          if (settled) {
            spawned.kill(priority: Isolate.immediate);
          } else {
            worker = spawned;
          }
        },
        onError: (Object _, StackTrace stackTrace) {
          completeWithError(
            const PaperPdfException('无法启动 PDF 解析 worker。'),
            stackTrace,
          );
        },
      ),
    );
    return completer.future;
  }

  static PaperPdfExtract _extractSynchronously({
    required String paperId,
    required String version,
    required Uint8List bytes,
    required int targetCharsPerChunk,
    required int maxPages,
    required int maxExtractedChars,
    required int maxChunks,
  }) {
    try {
      final pages = <({int page, String text})>[];
      final document = PdfDocument(inputBytes: bytes);
      try {
        if (document.pages.count > maxPages) {
          throw const PaperPdfException('PDF 页数超过安全解析上限。');
        }
        final extractor = PdfTextExtractor(document);
        var extractedChars = 0;
        for (var index = 0; index < document.pages.count; index++) {
          final text = extractor
              .extractText(startPageIndex: index, endPageIndex: index)
              .trim();
          if (text.isEmpty) continue;
          if (text.length > maxExtractedChars - extractedChars) {
            throw const PaperPdfException('PDF 提取文本超过安全字符上限。');
          }
          extractedChars += text.length;
          pages.add((page: index + 1, text: text));
        }
      } finally {
        document.dispose();
      }
      if (pages.isEmpty) {
        throw const PaperPdfException('无法从 PDF 中提取文本（可能是扫描件）。');
      }
      final chunks = _chunk(
        pages,
        targetChars: targetCharsPerChunk,
        maxExtractedChars: maxExtractedChars,
        maxChunks: maxChunks,
      );
      if (chunks.isEmpty) {
        throw const PaperPdfException('PDF 正文提取结果为空。');
      }
      return PaperPdfExtract(
        paperId: paperId,
        version: version,
        chunks: chunks,
        extractedAt: DateTime.now().toUtc(),
      );
    } on PaperPdfException {
      rethrow;
    } catch (_) {
      throw const PaperPdfException('PDF 解析失败，文件可能已损坏。');
    }
  }

  static bool _looksLikePdf(List<int> bytes) {
    if (bytes.length < 5) return false;
    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
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

  static List<PaperPdfChunk> _chunk(
    List<({int page, String text})> pages, {
    required int targetChars,
    required int maxExtractedChars,
    required int maxChunks,
  }) {
    final chunks = <PaperPdfChunk>[];
    final buffer = StringBuffer();
    var bufferStartPage = 1;
    var chunkChars = 0;

    void flush() {
      final text = buffer.toString().trim();
      if (text.isEmpty) return;
      if (chunks.length >= maxChunks) {
        throw const PaperPdfException('PDF 正文分块超过安全数量上限。');
      }
      if (text.length > maxExtractedChars - chunkChars) {
        throw const PaperPdfException('PDF 提取文本超过安全字符上限。');
      }
      chunks.add(
        PaperPdfChunk(
          index: chunks.length,
          text: text,
          pageNumber: bufferStartPage,
        ),
      );
      chunkChars += text.length;
      buffer.clear();
    }

    for (final page in pages) {
      final paragraphs = page.text.split(RegExp(r'\n\s*\n'));
      for (final rawParagraph in paragraphs) {
        final paragraph = rawParagraph.trim();
        if (paragraph.isEmpty) continue;
        for (final segment in _splitParagraph(paragraph, targetChars)) {
          final separatorLength = buffer.isEmpty ? 0 : 2;
          if (buffer.isNotEmpty &&
              buffer.length + separatorLength + segment.length > targetChars) {
            flush();
          }
          if (buffer.isEmpty) {
            bufferStartPage = page.page;
          } else {
            buffer.write('\n\n');
          }
          buffer.write(segment);
        }
      }
    }
    flush();
    return chunks;
  }

  static Iterable<String> _splitParagraph(
    String paragraph,
    int targetChars,
  ) sync* {
    var start = 0;
    while (start < paragraph.length) {
      var end = (start + targetChars).clamp(0, paragraph.length);
      if (end < paragraph.length) {
        final preferredStart = start + (targetChars ~/ 2);
        var candidate = end;
        while (candidate > preferredStart &&
            !_isPreferredBreak(paragraph.codeUnitAt(candidate - 1))) {
          candidate--;
        }
        if (candidate > preferredStart) end = candidate;
      }
      final segment = paragraph.substring(start, end).trim();
      if (segment.isNotEmpty) yield segment;
      start = end;
      while (start < paragraph.length &&
          _isWhitespace(paragraph.codeUnitAt(start))) {
        start++;
      }
    }
  }

  static bool _isPreferredBreak(int codeUnit) {
    return _isWhitespace(codeUnit) ||
        codeUnit == 0x2e ||
        codeUnit == 0x2c ||
        codeUnit == 0x3b ||
        codeUnit == 0x3a ||
        codeUnit == 0x21 ||
        codeUnit == 0x3f ||
        codeUnit == 0x3002 ||
        codeUnit == 0xff0c ||
        codeUnit == 0xff1b ||
        codeUnit == 0xff01 ||
        codeUnit == 0xff1f;
  }

  static bool _isWhitespace(int codeUnit) {
    return codeUnit == 0x20 ||
        codeUnit == 0x09 ||
        codeUnit == 0x0a ||
        codeUnit == 0x0d;
  }
}

void _extractPaperPdfInWorker(_PaperPdfWorkerRequest request) {
  try {
    final result = PaperPdfExtractionService._extractSynchronously(
      paperId: request.paperId,
      version: request.version,
      bytes: request.bytes.materialize().asUint8List(),
      targetCharsPerChunk: request.targetCharsPerChunk,
      maxPages: request.maxPages,
      maxExtractedChars: request.maxExtractedChars,
      maxChunks: request.maxChunks,
    );
    Isolate.exit(
      request.resultPort!,
      <Object?>[_paperPdfWorkerSuccess, result],
    );
  } on PaperPdfException catch (error, stackTrace) {
    Isolate.exit(
      request.resultPort!,
      <Object?>[_paperPdfWorkerFailure, error.message, stackTrace.toString()],
    );
  } catch (_, stackTrace) {
    Isolate.exit(
      request.resultPort!,
      <Object?>[
        _paperPdfWorkerFailure,
        'PDF 解析失败，文件可能已损坏。',
        stackTrace.toString(),
      ],
    );
  }
}

class _PaperPdfWorkerRequest {
  const _PaperPdfWorkerRequest({
    required this.paperId,
    required this.version,
    required this.bytes,
    required this.targetCharsPerChunk,
    required this.maxPages,
    required this.maxExtractedChars,
    required this.maxChunks,
    this.resultPort,
  });

  final String paperId;
  final String version;
  final TransferableTypedData bytes;
  final int targetCharsPerChunk;
  final int maxPages;
  final int maxExtractedChars;
  final int maxChunks;
  final SendPort? resultPort;

  _PaperPdfWorkerRequest withResultPort(SendPort resultPort) {
    return _PaperPdfWorkerRequest(
      paperId: paperId,
      version: version,
      bytes: bytes,
      targetCharsPerChunk: targetCharsPerChunk,
      maxPages: maxPages,
      maxExtractedChars: maxExtractedChars,
      maxChunks: maxChunks,
      resultPort: resultPort,
    );
  }
}

class PaperPdfException implements Exception {
  const PaperPdfException(this.message);

  final String message;

  @override
  String toString() => message;
}
