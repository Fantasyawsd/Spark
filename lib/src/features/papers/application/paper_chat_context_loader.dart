import '../../../core/diagnostics/diagnostics.dart';
import '../../chat/chat.dart';
import '../domain/paper.dart';
import '../domain/paper_keyword_repository.dart';
import '../domain/paper_pdf_content_provider.dart';
import 'paper_chat_context.dart';
import 'paper_keyword_service.dart';
import 'paper_pdf_context_builder.dart';

final class PaperChatContextLoader {
  const PaperChatContextLoader({
    required this.keywordRepository,
    required this.pdfContentProvider,
  });

  final PaperKeywordRepository keywordRepository;
  final PaperPdfContentProvider pdfContentProvider;

  Future<ChatContext> load(Paper paper, {bool includeFullText = false}) async {
    final keywords = await _loadFreshKeywords(paper);
    String? pdfContext;
    if (includeFullText) {
      final extract = await pdfContentProvider.load(paper);
      pdfContext = PaperPdfContextBuilder.buildContextChunk(extract.chunks);
    }
    return PaperChatContext.fromPaper(
      paper,
      generatedKeywords: keywords,
      pdfContext: pdfContext,
    );
  }

  Future<List<String>> _loadFreshKeywords(Paper paper) async {
    try {
      final record = await keywordRepository.load(paper.id);
      if (record == null || !isPaperKeywordRecordFresh(record, paper)) {
        return const [];
      }
      return record.keywords;
    } on Exception catch (error, stackTrace) {
      SparkDiagnostics.reportUnexpected(
        operation: SparkDiagnosticOperation.paperChatContextKeywordsLoad,
        error: error,
        stackTrace: stackTrace,
        severity: SparkDiagnosticSeverity.warning,
      );
      return const [];
    }
  }
}
