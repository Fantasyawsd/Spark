import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../domain/paper_pdf.dart';
import 'paper_pdf_chunker.dart';
import 'paper_pdf_downloader.dart';

const paperPdfExtractionVersion = 2;
const paperPdfDefaultTargetCharsPerChunk = 1800;
// Kept at this boundary for callers that previously configured downloads
// through the extraction service constructor.
const paperPdfDefaultMaxDownloadBytes = 32 * 1024 * 1024;
const paperPdfDefaultMaxInputBytes = paperPdfDefaultMaxDownloadBytes;
const paperPdfDefaultMaxPages = 300;
const paperPdfDefaultMaxExtractedChars = 1000000;
const paperPdfDefaultMaxChunks = 1024;
const paperPdfDefaultExtractionTimeout = Duration(seconds: 30);

const _paperPdfWorkerSuccess = 0;
const _paperPdfWorkerFailure = 1;
const _paperPdfWorkerUnexpectedFailure = 2;

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
    int maxDownloadBytes = paperPdfDefaultMaxDownloadBytes,
    Duration downloadTimeout = const Duration(seconds: 60),
    PaperPdfDownloader? downloader,
    this.maxInputBytes = paperPdfDefaultMaxInputBytes,
    this.maxPages = paperPdfDefaultMaxPages,
    this.maxExtractedChars = paperPdfDefaultMaxExtractedChars,
    this.maxChunks = paperPdfDefaultMaxChunks,
    this.extractionTimeout = paperPdfDefaultExtractionTimeout,
  }) : _downloader = downloader ??
            PaperPdfDownloader(
              client: client,
              maxDownloadBytes: maxDownloadBytes,
              downloadTimeout: downloadTimeout,
            );

  final PaperPdfDownloader _downloader;
  final int maxInputBytes;
  final int maxPages;
  final int maxExtractedChars;
  final int maxChunks;
  final Duration extractionTimeout;

  /// 下载 PDF 字节；非 2xx 或内容不是 PDF 时抛出 [PaperPdfException]。
  Future<List<int>> download(Uri url) => _downloader.download(url);

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
    if (!looksLikePaperPdf(bytes)) {
      throw const PaperPdfException('不是有效的 PDF 文件。');
    }
    final typedBytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final transferable = TransferableTypedData.fromList([typedBytes]);
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

  Future<PaperPdfExtract> _runExtractionWorker(_PaperPdfWorkerRequest request) {
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
        case _paperPdfWorkerUnexpectedFailure:
          final stack = message.length > 1 ? message[1] : null;
          final stackTrace = StackTrace.fromString(
            stack is String ? stack : '',
          );
          completeWithError(
            const PaperPdfException('PDF 解析失败，文件可能已损坏。'),
            stackTrace,
          );
          return;
      }
      completeWithError(
        const PaperPdfException('PDF 解析 worker 返回了无效结果。'),
        StackTrace.current,
      );
    });
    errorPort.listen((message) {
      final stack = message is List && message.length > 1 ? message[1] : null;
      final stackTrace = StackTrace.fromString(stack is String ? stack : '');
      completeWithError(
        const PaperPdfException('PDF 解析失败，文件可能已损坏。'),
        stackTrace,
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
        onError: (Object error, StackTrace stackTrace) {
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
      final pages = <PaperPdfPageText>[];
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
      final chunks = chunkPaperPdfPages(
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
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        const _PaperPdfWorkerUnexpectedException(),
        stackTrace,
      );
    }
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
    Isolate.exit(request.resultPort!, <Object?>[
      _paperPdfWorkerSuccess,
      result,
    ]);
  } on PaperPdfException catch (error, stackTrace) {
    Isolate.exit(request.resultPort!, <Object?>[
      _paperPdfWorkerFailure,
      error.message,
      stackTrace.toString(),
    ]);
  } on Object catch (error, stackTrace) {
    Isolate.exit(request.resultPort!, <Object?>[
      _paperPdfWorkerUnexpectedFailure,
      stackTrace.toString(),
    ]);
  }
}

final class _PaperPdfWorkerUnexpectedException implements Exception {
  const _PaperPdfWorkerUnexpectedException();
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
