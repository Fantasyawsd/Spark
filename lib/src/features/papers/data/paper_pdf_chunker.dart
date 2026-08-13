import '../domain/paper_pdf.dart';

/// Extracted page text passed to the pure chunking pipeline.
typedef PaperPdfPageText = ({int page, String text});

List<PaperPdfChunk> chunkPaperPdfPages(
  List<PaperPdfPageText> pages, {
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
      for (final segment in splitPaperPdfParagraph(paragraph, targetChars)) {
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

Iterable<String> splitPaperPdfParagraph(
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
          !_isPreferredPaperPdfBreak(paragraph.codeUnitAt(candidate - 1))) {
        candidate--;
      }
      if (candidate > preferredStart) end = candidate;
    }
    final segment = paragraph.substring(start, end).trim();
    if (segment.isNotEmpty) yield segment;
    start = end;
    while (start < paragraph.length &&
        _isPaperPdfWhitespace(paragraph.codeUnitAt(start))) {
      start++;
    }
  }
}

bool _isPreferredPaperPdfBreak(int codeUnit) {
  return _isPaperPdfWhitespace(codeUnit) ||
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

bool _isPaperPdfWhitespace(int codeUnit) {
  return codeUnit == 0x20 ||
      codeUnit == 0x09 ||
      codeUnit == 0x0a ||
      codeUnit == 0x0d;
}
