import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/spark.dart';
import 'package:spark/src/features/papers/data/arxiv_seed_repository.dart';
import 'package:spark/src/features/papers/data/in_memory_paper_comment_repository.dart';
import 'package:spark/src/features/papers/data/in_memory_paper_interaction_repository.dart';
import 'package:spark/src/features/papers/data/in_memory_paper_reading_repository.dart';
import 'package:spark/src/features/papers/presentation/papers_screen.dart';
import 'package:spark/src/features/papers/presentation/widgets/paper_comments_sheet.dart';

import 'support/demo_paper_repository.dart';
import 'support/paper_presentation_test_support.dart';

void main() {
  testWidgets('favorite tap uses default group and long press selects groups', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = InMemoryPaperInteractionRepository();
    final paper = const ArxivSeedRepository().getAll().first;

    await tester.pumpWidget(
      SparkApp(
        showSplash: false,
        dependencies: SparkDependencies.preview(
          interactionRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('paper-action-save')).first);
    await tester.pumpAndSettle();
    expect(
      (await repository.load()).favoritePaperIdsByGroup[defaultFavoriteGroupId],
      contains(paper.id),
    );

    await tester.longPress(
      find.byKey(const ValueKey('paper-action-save')).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('收藏到分组'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('favorite-group-default')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('create-favorite-group')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('favorite-group-name-input')),
      '重点阅读',
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm-create-favorite-group')),
    );
    await tester.pumpAndSettle();

    final snapshot = await repository.load();
    final customGroup = snapshot.favoriteGroups.singleWhere(
      (group) => group.name == '重点阅读',
    );
    expect(
      snapshot.favoritePaperIdsByGroup[customGroup.id],
      contains(paper.id),
    );

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bottom-nav-2')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('profile-favorite-group-${customGroup.id}')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('profile-saved-paper-${paper.id}')),
      findsOneWidget,
    );
  });

  testWidgets('read later and reading history appear in profile', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = InMemoryPaperReadingRepository();

    await tester.pumpWidget(
      SparkApp(
        showSplash: false,
        dependencies: SparkDependencies.preview(readingRepository: repository),
      ),
    );
    await tester.pumpAndSettle();
    final paper = const ArxivSeedRepository().getAll().first;

    await tester.tap(find.byKey(const ValueKey('paper-action-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加入稍后阅读'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bottom-nav-2')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey('profile-read-later-paper-${paper.id}')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(ValueKey('profile-read-later-paper-${paper.id}')),
    );
    await tester.drag(
      find.byKey(const ValueKey('profile-scroll')),
      const Offset(0, -140),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('profile-read-later-paper-${paper.id}')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('paper-title-${paper.id}')), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(ValueKey('profile-history-paper-${paper.id}')),
      220,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('profile-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      find.byKey(ValueKey('profile-history-paper-${paper.id}')),
      findsOneWidget,
    );
  });

  testWidgets('comments sheet switches to AI conversation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const SparkApp(showSplash: false));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('评论 0'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
    expect(find.text('还没有评论，来发表第一条看法吧'), findsOneWidget);

    final halfHeight = tester
        .getSize(find.byKey(const ValueKey('paper-comments-sheet')))
        .height;
    final contentSize = tester.getSize(
      find.byKey(const ValueKey('paper-sheet-pages')),
    );
    expect(halfHeight, inInclusiveRange(350, 450));

    await tester.drag(find.byType(SparkSheetHandle), const Offset(0, -220));
    await tester.pumpAndSettle();
    final draggedHeight = tester
        .getSize(find.byKey(const ValueKey('paper-comments-sheet')))
        .height;
    expect(draggedHeight, greaterThan(halfHeight));

    await tester.drag(find.byType(SparkSheetHandle), const Offset(0, 220));
    await tester.pumpAndSettle();
    final returnedHeight = tester
        .getSize(find.byKey(const ValueKey('paper-comments-sheet')))
        .height;
    expect(returnedHeight, lessThan(draggedHeight));

    await tester.tap(find.byTooltip('全屏'));
    await tester.pumpAndSettle();
    final fullHeight = tester
        .getSize(find.byKey(const ValueKey('paper-comments-sheet')))
        .height;
    expect(fullHeight, greaterThan(700));

    await tester.tap(find.byTooltip('恢复半屏'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();

    final aiContentSize = tester.getSize(
      find.byKey(const ValueKey('paper-ai-discussion-scroll')),
    );
    expect(aiContentSize.height, greaterThan(0));
    expect(aiContentSize.height, lessThanOrEqualTo(contentSize.height));
    expect(find.text('解释核心方法'), findsNothing);
    expect(find.byKey(const ValueKey('paper-ai-input')), findsOneWidget);
  });

  testWidgets('comments and local AI messages complete their send flow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final comments = PaperCommentController();
    addTearDown(comments.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showPaperCommentsSheet(
                context,
                demoPapers.first,
                aiDiscussionBuilder: paperAiDiscussionBuilder(
                  const FakeChatAiService(),
                ),
                commentController: comments,
              ),
              child: const Text('打开评论'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开评论'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '这是一条本地评论');
    await tester.pump();
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();
    expect(find.text('这是一条本地评论'), findsOneWidget);

    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '总结实验效果');
    await tester.pump();
    await tester.tap(find.byTooltip('发送'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.textContaining('DeepSeek Markdown'), findsOneWidget);
  });

  testWidgets('failed comment restores only the comment composer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _ControlledCommentWidgetRepository();
    final comments = PaperCommentController(repository: repository);
    addTearDown(comments.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showPaperCommentsSheet(
                context,
                demoPapers.first,
                aiDiscussionBuilder: paperAiDiscussionBuilder(
                  const FakeChatAiService(),
                ),
                commentController: comments,
              ),
              child: const Text('打开失败评论'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开失败评论'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('paper-comment-input')),
      '需要重试的评论',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('paper-comment-send')));
    await tester.pump();

    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();
    repository.failSave();
    await tester.pumpAndSettle();

    final aiInput = tester.widget<TextField>(
      find.byKey(const ValueKey('paper-ai-input')),
    );
    expect(aiInput.controller!.text, isEmpty);

    await tester.tap(find.textContaining('评论 '));
    await tester.pumpAndSettle();
    expect(find.text('需要重试的评论'), findsOneWidget);
  });

  testWidgets('interaction failure is reported after papers reactivate', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _ControlledInteractionWidgetRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: SparkShell(
          dependencies: SparkDependencies.preview(
            interactionRepository: repository,
            aiService: const FakeChatAiService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('点赞').first);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('bottom-nav-1')));
    await tester.pumpAndSettle();
    repository.failSave();
    await tester.pump();
    expect(find.text('保存互动失败'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('bottom-nav-0')));
    await tester.pumpAndSettle();
    expect(find.text('保存互动失败'), findsOneWidget);
  });

  testWidgets('paper action count updates after a local comment is sent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = InMemoryPaperCommentRepository();

    await tester.pumpWidget(
      SparkApp(
        showSplash: false,
        dependencies: SparkDependencies.preview(commentRepository: repository),
      ),
    );
    await tester.pumpAndSettle();

    final action = find.byKey(const ValueKey('paper-action-comment'));
    expect(
      find.descendant(of: action, matching: find.text('0')),
      findsOneWidget,
    );

    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '计数同步评论');
    await tester.pump();
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();
    Navigator.of(
      tester.element(find.byKey(const ValueKey('paper-comments-sheet'))),
    ).pop();
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: action, matching: find.text('1')),
      findsOneWidget,
    );
  });

  testWidgets('comments, replies and likes persist per paper', (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = InMemoryPaperCommentRepository();
    final comments = PaperCommentController(repository: repository);
    addTearDown(comments.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showPaperCommentsSheet(
                context,
                demoPapers.first,
                aiDiscussionBuilder: paperAiDiscussionBuilder(
                  const FakeChatAiService(),
                ),
                commentController: comments,
              ),
              child: const Text('打开持久评论'),
            ),
          ),
        ),
      ),
    );

    Future<void> openSheet() async {
      await tester.tap(find.text('打开持久评论'));
      await tester.pumpAndSettle();
    }

    await openSheet();
    await tester.enterText(find.byType(TextField), '我的本地评论');
    await tester.pump();
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();
    expect(find.text('评论 1'), findsOneWidget);

    await tester.tap(find.text('回复').first);
    await tester.enterText(find.byType(TextField), '我的本地回复');
    await tester.pump();
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();
    expect(find.text('我的本地回复'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded).first);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    await openSheet();
    expect(find.text('我的本地评论'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    await tester.tap(find.text('展开 1 条回复'));
    await tester.pumpAndSettle();
    expect(find.text('我的本地回复'), findsOneWidget);

    await tester.tap(find.byTooltip('删除评论').first);
    await tester.pumpAndSettle();
    expect(find.text('我的本地评论'), findsNothing);
    expect(find.text('评论 0'), findsOneWidget);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    await openSheet();
    expect(find.text('我的本地评论'), findsNothing);
  });

  testWidgets('sharing a paper calls the service and updates its count', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final feed = PaperFeedController(const ArxivSeedRepository());
    final interactions = PaperInteractionController();
    final comments = PaperCommentController();
    final shareService = _FakePaperShareService(PaperShareResult.copied);
    addTearDown(feed.dispose);
    addTearDown(interactions.dispose);
    addTearDown(comments.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PapersScreen(
            readingController: PaperReadingController(),
            feedController: feed,
            interactionController: interactions,
            commentController: comments,
            aiDiscussionBuilder: paperAiDiscussionBuilder(
              const FakeChatAiService(),
            ),
            keywordService: const FakeChatAiService(),
            translationServiceFactory:
                const FakePaperTranslationServiceFactory(),
            shareService: shareService,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('paper-action-share')));
    await tester.pumpAndSettle();

    expect(shareService.payloads, hasLength(1));
    expect(shareService.payloads.single.subject, feed.papers.first.title);
    expect(interactions.shareCountDelta(feed.papers.first.id), 1);
    expect(find.text('分享内容已复制'), findsOneWidget);
  });
}

class _ControlledCommentWidgetRepository implements PaperCommentRepository {
  final Completer<void> _saveCompleter = Completer<void>();

  @override
  Future<PaperCommentSnapshot> load(String paperId) async =>
      const PaperCommentSnapshot(comments: [], hasStoredValue: false);

  @override
  Future<void> save(String paperId, List<PaperComment> comments) async {
    await _saveCompleter.future;
    throw const PaperCommentPersistenceException('保存评论失败');
  }

  void failSave() => _saveCompleter.complete();
}

class _ControlledInteractionWidgetRepository
    implements PaperInteractionRepository {
  final Completer<void> _saveCompleter = Completer<void>();

  @override
  Future<PaperInteractionSnapshot> load() async => PaperInteractionSnapshot();

  @override
  Future<void> save(PaperInteractionSnapshot snapshot) async {
    await _saveCompleter.future;
    throw const PaperInteractionPersistenceException('保存互动失败');
  }

  void failSave() => _saveCompleter.complete();
}

class _FakePaperShareService implements PaperShareService {
  _FakePaperShareService(this.result);

  final PaperShareResult result;
  final List<PaperSharePayload> payloads = [];

  @override
  Future<PaperShareResult> share(PaperSharePayload payload) async {
    payloads.add(payload);
    return result;
  }
}
