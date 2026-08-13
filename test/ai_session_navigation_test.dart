import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/spark.dart';
import 'package:spark/src/core/theme/spark_design_tokens.dart';
import 'package:spark/src/features/chat/data/in_memory_chat_session_repository.dart';
import 'package:spark/src/features/papers/data/arxiv_seed_repository.dart';

import 'support/paper_presentation_test_support.dart';

void main() {
  testWidgets('paper AI sessions appear in the global chat entry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = InMemoryChatSessionRepository();
    final paper = const ArxivSeedRepository().getAll().first;
    await repository.save(paper.id, const [
      ChatMessage(fromUser: true, content: '解释这篇论文'),
      ChatMessage(fromUser: false, content: '这是论文回答'),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: SparkShell(
          dependencies: SparkDependencies.preview(
            aiService: const FakeChatAiService(),
            aiSessionRepository: repository,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('bottom-nav-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai-chat-home-title')), findsOneWidget);
    expect(find.text('Spark 主聊天'), findsOneWidget);
    expect(find.text(paper.title), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('ai-session-${paper.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('global-paper-ai-chat')), findsOneWidget);
  });

  testWidgets('main AI chat stays pinned above paper sessions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: SparkShell(
          dependencies: SparkDependencies.preview(
            aiService: const FakeChatAiService(),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('bottom-nav-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('main-ai-chat')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('main-ai-chat')));
    await tester.pumpAndSettle();
    expect(find.text('主聊天'), findsOneWidget);
    expect(find.text('今天想研究什么？'), findsOneWidget);
    expect(find.byKey(const ValueKey('paper-ai-input')), findsOneWidget);
  });

  testWidgets('AI session left swipe can pin and delete', (tester) async {
    await tester.binding.setSurfaceSize(const Size(378, 810));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = InMemoryChatSessionRepository();
    final paper = const ArxivSeedRepository().getAll().first;
    await repository.save(paper.id, const [
      ChatMessage(fromUser: true, content: '分析这篇论文'),
      ChatMessage(fromUser: false, content: '会话回答'),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: SparkShell(
          dependencies: SparkDependencies.preview(
            aiService: const FakeChatAiService(),
            aiSessionRepository: repository,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('bottom-nav-1')));
    await tester.pumpAndSettle();

    final sessionCard = find.byKey(ValueKey('ai-session-${paper.id}'));
    await tester.drag(sessionCard, const Offset(-180, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('ai-session-pin-${paper.id}')), findsOneWidget);
    expect(
      find.byKey(ValueKey('ai-session-delete-${paper.id}')),
      findsOneWidget,
    );
    final actionsClip = tester.widget<ClipRRect>(
      find.byKey(ValueKey('ai-session-actions-${paper.id}')),
    );
    expect(
      actionsClip.borderRadius,
      const BorderRadius.all(Radius.circular(SparkDesignTokens.radius2Xl)),
    );

    await tester.tap(find.byKey(ValueKey('ai-session-pin-${paper.id}')));
    await tester.pumpAndSettle();
    expect((await repository.listSessions()).single.pinned, isTrue);

    await tester.drag(sessionCard, const Offset(-180, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('ai-session-delete-${paper.id}')));
    await tester.pumpAndSettle();
    expect(find.text('删除对话？'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-delete-ai-session')));
    await tester.pumpAndSettle();

    expect(await repository.listSessions(), isEmpty);
    expect(sessionCard, findsNothing);
    expect(find.byKey(const ValueKey('main-ai-chat')), findsOneWidget);
  });
}
