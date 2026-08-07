import '../domain/paper_pdf.dart';

class PaperPdfJsonMapper {
  const PaperPdfJsonMapper._();

  static Map<String, dynamic> toJson(PaperPdfExtract extract) {
    return {
      'version': extract.version,
      'extractedAt': extract.extractedAt.toUtc().toIso8601String(),
      'chunks': [
        for (final chunk in extract.chunks)
          {
            'index': chunk.index,
            'text': chunk.text,
            if (chunk.pageNumber != null) 'pageNumber': chunk.pageNumber,
            if (chunk.heading != null) 'heading': chunk.heading,
          },
      ],
    };
  }

  static PaperPdfExtract fromJson(String paperId, Map<String, dynamic> json) {
    final version = json['version'];
    final extractedAt = json['extractedAt'];
    final rawChunks = json['chunks'];
    if (paperId.trim().isEmpty ||
        version is! String ||
        version.trim().isEmpty ||
        extractedAt is! String ||
        rawChunks is! List ||
        rawChunks.isEmpty) {
      throw const FormatException('PDF 提取缓存记录无效。');
    }
    final parsedExtractedAt = DateTime.tryParse(extractedAt);
    if (parsedExtractedAt == null) {
      throw const FormatException('PDF 提取缓存时间无效。');
    }
    final chunks = <PaperPdfChunk>[];
    for (var expectedIndex = 0;
        expectedIndex < rawChunks.length;
        expectedIndex++) {
      final raw = rawChunks[expectedIndex];
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('PDF 提取缓存分块必须是对象。');
      }
      final index = raw['index'];
      final text = raw['text'];
      final pageNumber = raw['pageNumber'];
      final heading = raw['heading'];
      if (index is! int ||
          index != expectedIndex ||
          text is! String ||
          text.trim().isEmpty ||
          (pageNumber != null && (pageNumber is! int || pageNumber <= 0)) ||
          (heading != null && (heading is! String || heading.trim().isEmpty))) {
        throw const FormatException('PDF 提取缓存分块无效。');
      }
      chunks.add(
        PaperPdfChunk(
          index: index,
          text: text,
          pageNumber: pageNumber as int?,
          heading: heading as String?,
        ),
      );
    }
    return PaperPdfExtract(
      paperId: paperId,
      version: version,
      chunks: List.unmodifiable(chunks),
      extractedAt: parsedExtractedAt.toUtc(),
    );
  }

  static void validatePayload(Object? payload) {
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('PDF 提取缓存必须是对象。');
    }
    for (final entry in payload.entries) {
      if (entry.value is! Map<String, dynamic>) {
        throw const FormatException('PDF 提取缓存记录必须是对象。');
      }
      fromJson(entry.key, entry.value as Map<String, dynamic>);
    }
  }
}
