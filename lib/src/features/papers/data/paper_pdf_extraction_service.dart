import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../domain/paper_pdf.dart';

/// 论文 PDF 的下载、文本提取与分块服务。
///
/// 遵循「DeepSeek 不直接上传 PDF」约束：客户端先提取文本，再按块注入
/// 上下文。提取结果由调用方通过 [PaperPdfRepository] 缓存。
class PaperPdfExtractionService {
  PaperPdfExtractionService({http.Client? client}) : _injectedClient = client;

  final http.Client? _injectedClient;

  /// 下载 PDF 字节；非 2xx 或内容不是 PDF 时抛出 [PaperPdfException]。
  Future<List<int>> download(Uri url) async {
    final client = _injectedClient ?? http.Client();
    try {
      final response =
          await client.get(url).timeout(const Duration(seconds: 60));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PaperPdfException('PDF 下载失败（HTTP ${response.statusCode}）。');
      }
      if (!_looksLikePdf(response.bodyBytes)) {
        throw const PaperPdfException('下载的内容不是有效的 PDF。');
      }
      return response.bodyBytes;
    } on PaperPdfException {
      rethrow;
    } on Exception {
      throw const PaperPdfException('无法下载 PDF，请检查网络后重试。');
    } finally {
      if (_injectedClient == null) client.close();
    }
  }

  /// 从 PDF 字节提取文本并按目标长度分块。
  PaperPdfExtract extract({
    required String paperId,
    required String version,
    required List<int> bytes,
    int targetCharsPerChunk = 1800,
  }) {
    if (!_looksLikePdf(bytes)) {
      throw const PaperPdfException('不是有效的 PDF 文件。');
    }
    try {
      final pages = <({int page, String text})>[];
      final document = PdfDocument(inputBytes: Uint8List.fromList(bytes));
      try {
        final extractor = PdfTextExtractor(document);
        for (var index = 0; index < document.pages.count; index++) {
          final text = extractor
              .extractText(startPageIndex: index, endPageIndex: index)
              .trim();
          if (text.isEmpty) continue;
          pages.add((page: index + 1, text: text));
        }
      } finally {
        document.dispose();
      }
      if (pages.isEmpty) {
        throw const PaperPdfException('无法从 PDF 中提取文本（可能是扫描件）。');
      }
      final chunks = _chunk(pages, targetChars: targetCharsPerChunk);
      if (chunks.isEmpty) {
        throw const PaperPdfException('PDF 正文提取结果为空。');
      }
      return PaperPdfExtract(
        paperId: paperId,
        version: version,
        chunks: chunks,
        extractedAt: DateTime.now(),
      );
    } on PaperPdfException {
      rethrow;
    } on Exception {
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

  static List<PaperPdfChunk> _chunk(
    List<({int page, String text})> pages, {
    required int targetChars,
  }) {
    final chunks = <PaperPdfChunk>[];
    final buffer = StringBuffer();
    var bufferStartPage = 1;

    void flush() {
      final text = buffer.toString().trim();
      if (text.isEmpty) return;
      chunks.add(
        PaperPdfChunk(
          index: chunks.length,
          text: text,
          pageNumber: bufferStartPage,
        ),
      );
      buffer.clear();
    }

    for (final page in pages) {
      final paragraphs = page.text.split(RegExp(r'\n\s*\n'));
      for (final rawParagraph in paragraphs) {
        final paragraph = rawParagraph.trim();
        if (paragraph.isEmpty) continue;
        if (buffer.isNotEmpty &&
            buffer.length + paragraph.length > targetChars) {
          flush();
        }
        if (buffer.isEmpty) bufferStartPage = page.page;
        buffer.writeln(paragraph);
      }
    }
    flush();
    return chunks;
  }
}

class PaperPdfException implements Exception {
  const PaperPdfException(this.message);

  final String message;

  @override
  String toString() => message;
}
