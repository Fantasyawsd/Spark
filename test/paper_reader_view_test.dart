import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/chat/chat.dart';
import 'package:spark/src/features/papers/application/paper_comment_controller.dart';
import 'package:spark/src/features/papers/application/paper_interaction_controller.dart';
import 'package:spark/src/features/papers/application/paper_reading_controller.dart';
import 'package:spark/src/features/papers/application/paper_translation_service.dart';
import 'package:spark/src/features/papers/data/arxiv_seed_repository.dart';
import 'package:spark/src/features/papers/domain/paper.dart';
import 'package:spark/src/features/papers/domain/paper_keyword_record.dart';
import 'package:spark/src/features/papers/domain/paper_keyword_repository.dart';
import 'package:spark/src/features/papers/domain/paper_translation.dart';
import 'package:spark/src/features/papers/presentation/widgets/paper_reader_card.dart';
import 'package:spark/src/features/papers/presentation/widgets/paper_reader_view.dart';

void main() {
  testWidgets('reader initializes only the active tab cache once',
      (tester) async {
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
            onComment: () {},
            onAnalyze: () {},
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
  });

  testWidgets('keyword cache failure reports and still opens discussion',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final interactions = PaperInteractionController();
    final comments = PaperCommentController();
    final reading = PaperReadingController();
    addTearDown(interactions.dispose);
    addTearDown(comments.dispose);
    addTearDown(reading.dispose);

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

    expect(find.text('无法读取已生成的关键词，已使用空关键词继续'), findsOneWidget);
    expect(find.byKey(const ValueKey('paper-comments-sheet')), findsOneWidget);
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
  int loadCalls = 0;

  @override
  Future<void> clear(String paperId) async {}

  @override
  Future<PaperKeywordRecord?> load(String paperId) async {
    loadCalls++;
    return null;
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
