import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/src/features/papers/application/paper_pdf_context_builder.dart';
import 'package:paperflow/src/features/papers/data/paper_pdf_extraction_service.dart';
import 'package:paperflow/src/features/papers/domain/paper_pdf.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  group('PaperPdfExtractionService', () {
    test('extracts text and chunks multi-page PDFs with page labels', () async {
      final bytes = await _buildPdf(pages: 2);
      final service = PaperPdfExtractionService();

      final extract = service.extract(
        paperId: 'paper-1',
        version: 'v1',
        bytes: bytes,
      );

      expect(extract.chunks, isNotEmpty);
      final allText = extract.chunks.map((c) => c.text).join('\n');
      expect(allText, contains('Page 1 content'));
      expect(allText, contains('Page 2 content'));
      expect(extract.chunks.first.pageNumber, 1);
    });

    test('chunks respect the target size budget', () async {
      final bytes = await _buildPdf(pages: 3);
      final service = PaperPdfExtractionService();

      final extract = service.extract(
        paperId: 'paper-1',
        version: 'v1',
        bytes: bytes,
        targetCharsPerChunk: 120,
      );

      expect(extract.chunks.length, greaterThan(1));
      for (final chunk in extract.chunks) {
        expect(chunk.charCount, lessThanOrEqualTo(260));
      }
    });

    test('rejects non-PDF bytes as invalid', () async {
      final service = PaperPdfExtractionService();
      expect(
        () => service.extract(
          paperId: 'paper-1',
          version: 'v1',
          bytes: [0, 1, 2, 3, 4, 5],
        ),
        throwsA(isA<PaperPdfException>()),
      );
    });
  });

  group('PaperPdfContextBuilder', () {
    test('builds traceable chunks with page labels', () {
      const chunks = [
        PaperPdfChunk(index: 0, text: '引言内容', pageNumber: 1),
        PaperPdfChunk(index: 1, text: '方法内容', pageNumber: 2),
      ];

      final context = PaperPdfContextBuilder.buildContextChunk(chunks);

      expect(context, contains('【第 1 页】'));
      expect(context, contains('【第 2 页】'));
      expect(context, contains('引言内容'));
      expect(context, contains('方法内容'));
    });

    test('respects the character budget and drops later chunks', () {
      final chunks = [
        for (var i = 0; i < 10; i++)
          PaperPdfChunk(index: i, text: 'x' * 1000, pageNumber: i + 1),
      ];

      final context =
          PaperPdfContextBuilder.buildContextChunk(chunks, maxChars: 1200);

      expect(context, contains('【第 1 页】'));
      expect(context, isNot(contains('【第 9 页】')));
    });
  });
}

Future<Uint8List> _buildPdf({required int pages}) async {
  final writer = PdfDocument();
  for (var pageNumber = 1; pageNumber <= pages; pageNumber++) {
    final page = writer.pages.add();
    page.graphics.drawString(
      'Page $pageNumber content with enough words to extract.',
      PdfStandardFont(PdfFontFamily.helvetica, 12),
    );
  }
  final bytes = await writer.save();
  writer.dispose();
  return Uint8List.fromList(bytes);
}
