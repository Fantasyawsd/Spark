import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/core/diagnostics/diagnostics.dart';
import 'package:spark/src/features/chat/chat.dart';
import 'package:spark/src/features/papers/application/paper_comment_controller.dart';
import 'package:spark/src/features/papers/application/paper_interaction_controller.dart';
import 'package:spark/src/features/papers/application/paper_keyword_service.dart';
import 'package:spark/src/features/papers/application/paper_reading_controller.dart';
import 'package:spark/src/features/papers/application/paper_translation_service.dart';
import 'package:spark/src/features/papers/data/arxiv_seed_repository.dart';
import 'package:spark/src/features/papers/domain/paper.dart';
import 'package:spark/src/features/papers/domain/paper_keyword_record.dart';
import 'package:spark/src/features/papers/domain/paper_keyword_repository.dart';
import 'package:spark/src/features/papers/domain/paper_link_service.dart';
import 'package:spark/src/features/papers/domain/paper_share.dart';
import 'package:spark/src/features/papers/domain/paper_translation.dart';
import 'package:spark/src/features/papers/presentation/widgets/paper_reader_card.dart';
import 'package:spark/src/features/papers/presentation/widgets/paper_reader_view.dart';

void main() {
  testWidgets('reader initializes only the active tab cache once', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final translationRepository = _CountingTranslationRepository();
    final keywordRepository = _CountingKeywordRepository();
    const translationFactory = _FakeTranslationServiceFactory();
    const aiService = _FakeAiService();
    final paper = const ArxivSeedRepository().getAll().first;

    Widget buildReader({required bool active}) {
      return MaterialApp(
        home: Scaffold(
          body: PaperReaderCard(
            paper: paper,
            liked: false,
            saved: false,
            read: false,
            readLater: false,
            followed: false,
            shareCountDelta: 0,
            commentCountDelta: 0,
            onLike: () {},
            onSave: () {},
            onSaveLongPress: () {},
            onToggleRead: () {},
            onToggleReadLater: () {},
            onFollow: () {},
            onComment: (_, {required keywordCacheFailed}) {},
            onAnalyze: (_, {required keywordCacheFailed}) {},
            onShare: () {},
            translationServiceFactory: translationFactory,
            keywordService: aiService,
            translationRepository: translationRepository,
            keywordRepository: keywordRepository,
            active: active,
            actionBarBottomInset: 0,
          ),
        ),
      );
    }

    await tester.pumpWidget(buildReader(active: false));
    await tester.pump();
    expect(translationRepository.loadCalls, 0);
    expect(keywordRepository.loadCalls, 0);

    await tester.pumpWidget(buildReader(active: true));
    await tester.pump();
    expect(translationRepository.loadCalls, 0);
    expect(keywordRepository.loadCalls, 0);

    await tester.tap(find.text('摘要'));
    await tester.pumpAndSettle();
    expect(translationRepository.loadCalls, 1);
    expect(keywordRepository.loadCalls, 0);

    await tester.tap(find.text('Abstract'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('摘要'));
    await tester.pumpAndSettle();
    expect(translationRepository.loadCalls, 1);

    await tester.tap(find.text('关键词'));
    await tester.pumpAndSettle();
    expect(keywordRepository.loadCalls, 1);

    await tester.tap(find.text('Abstract'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('关键词'));
    await tester.pumpAndSettle();
    expect(keywordRepository.loadCalls, 1);

    await tester.tap(find.byKey(const ValueKey('paper-action-comment')));
    await tester.pumpAndSettle();
    expect(keywordRepository.loadCalls, 1);
  });

  testWidgets('keyword cache failure reports and still opens discussion', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final interactions = PaperInteractionController();
    final comments = PaperCommentController();
    final reading = PaperReadingController();
    addTearDown(interactions.dispose);
    addTearDown(comments.dispose);
    addTearDown(reading.dispose);
    final events = <SparkDiagnosticEvent>[];

    await SparkDiagnostics.runWithSink(events.add, () async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaperReaderView(
              paper: const ArxivSeedRepository().getAll().first,
              interactionController: interactions,
              commentController: comments,
              readingController: reading,
              aiDiscussionBuilder: (
                context, {
                required paper,
                required generatedKeywords,
                required scrollController,
              }) =>
                  const SizedBox.shrink(),
              keywordService: const _FakeAiService(),
              translationServiceFactory: const _FakeTranslationServiceFactory(),
              keywordRepository: _ThrowingKeywordRepository(),
              actionBarBottomInset: 0,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('paper-action-comment')));
      await tester.pumpAndSettle();
    });

    expect(find.text('无法读取已生成的关键词，已使用空关键词继续'), findsOneWidget);
    expect(find.byKey(const ValueKey('paper-comments-sheet')), findsOneWidget);
    expect(events.map((event) => event.operation), [
      SparkDiagnosticOperation.paperKeywordsLoad,
    ]);
  });

  testWidgets('discussion and keyword tab share one keyword cache load', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final interactions = PaperInteractionController();
    final comments = PaperCommentController();
    final reading = PaperReadingController();
    addTearDown(interactions.dispose);
    addTearDown(comments.dispose);
    addTearDown(reading.dispose);
    final paper = const ArxivSeedRepository().getAll().first;
    final keywordRepository = _CountingKeywordRepository(
      record: PaperKeywordRecord(
        paperId: paper.id,
        keywords: const [
          'shared keyword',
          'cache reuse',
          'paper reading',
          'discussion context',
          'keyword controller',
        ],
        inputFingerprint: paperKeywordInputFingerprint(paper),
        promptVersion: paperKeywordPromptVersion,
        generatedAt: DateTime.utc(2026, 8, 13),
      ),
    );
    List<String>? discussionKeywords;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaperReaderView(
            paper: paper,
            interactionController: interactions,
            commentController: comments,
            readingController: reading,
            aiDiscussionBuilder: (
              context, {
              required paper,
              required generatedKeywords,
              required scrollController,
            }) {
              discussionKeywords = generatedKeywords;
              return const SizedBox.shrink();
            },
            keywordService: const _FakeAiService(),
            translationServiceFactory: const _FakeTranslationServiceFactory(),
            keywordRepository: keywordRepository,
            actionBarBottomInset: 0,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('paper-action-comment')));
    await tester.pumpAndSettle();

    expect(keywordRepository.loadCalls, 1);
    expect(discussionKeywords, [
      'shared keyword',
      'cache reuse',
      'paper reading',
      'discussion context',
      'keyword controller',
    ]);

    Navigator.of(
      tester.element(find.byKey(const ValueKey('paper-comments-sheet'))),
    ).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('关键词'));
    await tester.pumpAndSettle();

    expect(keywordRepository.loadCalls, 1);
    expect(find.text('shared keyword'), findsOneWidget);
  });

  testWidgets('reader reports link and share failures with existing messages', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final interactions = PaperInteractionController();
    final comments = PaperCommentController();
    final reading = PaperReadingController();
    addTearDown(interactions.dispose);
    addTearDown(comments.dispose);
    addTearDown(reading.dispose);
    final events = <SparkDiagnosticEvent>[];

    await SparkDiagnostics.runWithSink(events.add, () async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaperReaderView(
              paper: const ArxivSeedRepository().getAll().first,
              interactionController: interactions,
              commentController: comments,
              readingController: reading,
              aiDiscussionBuilder: (
                context, {
                required paper,
                required generatedKeywords,
                required scrollController,
              }) =>
                  const SizedBox.shrink(),
              keywordService: const _FakeAiService(),
              translationServiceFactory: const _FakeTranslationServiceFactory(),
              linkService: const _ThrowingPaperLinkService(),
              shareService: const _ThrowingPaperShareService(),
              actionBarBottomInset: 0,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('paper-open-link')));
      await tester.pump();
      expect(find.text('无法打开论文链接'), findsOneWidget);
      ScaffoldMessenger.of(
        tester.element(find.byType(Scaffold)),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('paper-action-share')));
      await tester.pumpAndSettle();
      expect(find.text('无法分享论文。'), findsOneWidget);
    });

    expect(events.map((event) => event.operation), [
      SparkDiagnosticOperation.paperReaderOpenLink,
      SparkDiagnosticOperation.paperReaderShare,
    ]);
  });
}

class _CountingTranslationRepository implements PaperTranslationRepository {
  int loadCalls = 0;

  @override
  Future<void> clear(String paperId) async {}

  @override
  Future<PaperTranslationRecord?> load(String paperId) async {
    loadCalls++;
    return null;
  }

  @override
  Future<void> save(PaperTranslationRecord record) async {}
}

class _CountingKeywordRepository implements PaperKeywordRepository {
  _CountingKeywordRepository({this.record});

  final PaperKeywordRecord? record;
  int loadCalls = 0;

  @override
  Future<void> clear(String paperId) async {}

  @override
  Future<PaperKeywordRecord?> load(String paperId) async {
    loadCalls++;
    return record;
  }

  @override
  Future<void> save(PaperKeywordRecord record) async {}
}

class _ThrowingKeywordRepository implements PaperKeywordRepository {
  @override
  Future<void> clear(String paperId) async {}

  @override
  Future<PaperKeywordRecord?> load(String paperId) =>
      Future<PaperKeywordRecord?>.error(StateError('cache unavailable'));

  @override
  Future<void> save(PaperKeywordRecord record) async {}
}

class _FakeTranslationServiceFactory implements PaperTranslationServiceFactory {
  const _FakeTranslationServiceFactory();

  @override
  PaperTranslationService create() => const _FakeTranslationService();
}

class _FakeTranslationService implements PaperTranslationService {
  const _FakeTranslationService();

  @override
  void cancelActiveTranslation() {}

  @override
  Stream<String> translateAbstract(Paper paper) async* {
    yield '中文摘要';
  }
}

class _FakeAiService implements ChatAiService {
  const _FakeAiService();

  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async =>
      '["keyword 1", "keyword 2", "keyword 3", "keyword 4", "keyword 5"]';
}

class _ThrowingPaperLinkService implements PaperLinkService {
  const _ThrowingPaperLinkService();

  @override
  Future<bool> open(Uri uri) async {
    throw StateError('private-link-details');
  }
}

class _ThrowingPaperShareService implements PaperShareService {
  const _ThrowingPaperShareService();

  @override
  Future<PaperShareResult> share(PaperSharePayload payload) async {
    throw const PaperShareException('无法分享论文。');
  }
}
