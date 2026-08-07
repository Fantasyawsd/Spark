import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/papers/application/paper_chat_context_loader.dart';
import 'package:spark/src/features/papers/application/paper_keyword_service.dart';
import 'package:spark/src/features/papers/domain/paper.dart';
import 'package:spark/src/features/papers/domain/paper_keyword_record.dart';
import 'package:spark/src/features/papers/domain/paper_keyword_repository.dart';
import 'package:spark/src/features/papers/domain/paper_pdf.dart';
import 'package:spark/src/features/papers/domain/paper_pdf_content_provider.dart';

void main() {
  test('keyword cache failures do not block opening paper chat', () async {
    final loader = PaperChatContextLoader(
      keywordRepository: _ThrowingKeywordRepository(),
      pdfContentProvider: _FakePdfContentProvider(),
    );

    final context = await loader.load(_paper);

    expect(context.systemPrompt, contains('内容关键词：未知'));
  });

  test('full text context combines fresh keywords and cached PDF chunks',
      () async {
    final keywordRepository = _KeywordRepository(
      PaperKeywordRecord(
        paperId: _paper.id,
        keywords: const ['alpha', 'beta', 'gamma', 'delta', 'epsilon'],
        inputFingerprint: paperKeywordInputFingerprint(_paper),
        promptVersion: paperKeywordPromptVersion,
        generatedAt: DateTime.utc(2026, 8, 7),
      ),
    );
    final loader = PaperChatContextLoader(
      keywordRepository: keywordRepository,
      pdfContentProvider: _FakePdfContentProvider(),
    );

    final context = await loader.load(_paper, includeFullText: true);

    expect(
        context.systemPrompt, contains('alpha, beta, gamma, delta, epsilon'));
    expect(context.systemPrompt, contains('【第 2 页】'));
    expect(context.systemPrompt, contains('PDF body'));
  });
}

final _paper = Paper(
  id: 'paper-1',
  title: 'Paper title',
  authors: const ['Author'],
  abstractText: 'Abstract text.',
  chineseAbstractMarkdown: '',
  readMinutes: 3,
  pdfUrl: 'https://example.test/paper.pdf',
);

class _KeywordRepository implements PaperKeywordRepository {
  _KeywordRepository(this.record);

  final PaperKeywordRecord? record;

  @override
  Future<void> clear(String paperId) async {}

  @override
  Future<PaperKeywordRecord?> load(String paperId) async => record;

  @override
  Future<void> save(PaperKeywordRecord record) async {}
}

class _ThrowingKeywordRepository extends _KeywordRepository {
  _ThrowingKeywordRepository() : super(null);

  @override
  Future<PaperKeywordRecord?> load(String paperId) {
    throw const FormatException('broken keyword cache');
  }
}

class _FakePdfContentProvider implements PaperPdfContentProvider {
  @override
  Future<PaperPdfExtract> load(Paper paper) async => PaperPdfExtract(
        paperId: paper.id,
        version: 'v1',
        chunks: const [
          PaperPdfChunk(index: 0, pageNumber: 2, text: 'PDF body'),
        ],
        extractedAt: DateTime.utc(2026, 8, 7),
      );
}
