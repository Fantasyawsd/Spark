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
    return PaperPdfExtract(
      paperId: paperId,
      version: json['version'] as String? ?? '',
      chunks: [
        for (final raw
            in (json['chunks'] as List? ?? const []).whereType<Map>())
          PaperPdfChunk(
            index: (raw['index'] as num?)?.toInt() ?? 0,
            text: raw['text'] as String? ?? '',
            pageNumber: (raw['pageNumber'] as num?)?.toInt(),
            heading: raw['heading'] as String?,
          ),
      ],
      extractedAt:
          DateTime.tryParse(json['extractedAt'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }

  static void validatePayload(Object? payload) {
    if (payload != null && payload is! Map<String, dynamic>) {
      throw const FormatException('PDF 提取缓存必须是对象。');
    }
  }
}
