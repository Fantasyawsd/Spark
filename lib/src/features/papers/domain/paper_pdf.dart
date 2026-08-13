/// 论文 PDF 的一个可注入分块。保留页码以便可追溯引用。
class PaperPdfChunk {
  const PaperPdfChunk({
    required this.index,
    required this.text,
    this.pageNumber,
    this.heading,
  });

  final int index;
  final String text;
  final int? pageNumber;
  final String? heading;

  /// 引用标注，例如 `（第 3 页）`；无页码时退化为章节名。
  String get referenceLabel {
    if (pageNumber != null) return '第 $pageNumber 页';
    if (heading != null && heading!.trim().isNotEmpty) return heading!.trim();
    return '第 ${index + 1} 段';
  }

  int get charCount => text.length;
}

/// 论文 PDF 文本提取结果：按版本缓存，分块存储。
class PaperPdfExtract {
  const PaperPdfExtract({
    required this.paperId,
    required this.version,
    required this.chunks,
    required this.extractedAt,
  });

  final String paperId;
  final String version;
  final List<PaperPdfChunk> chunks;
  final DateTime extractedAt;

  int get charCount => chunks.fold(0, (sum, chunk) => sum + chunk.charCount);
}

class PaperPdfException implements Exception {
  const PaperPdfException(this.message);

  final String message;

  @override
  String toString() => message;
}
