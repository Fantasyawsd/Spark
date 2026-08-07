import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/spark.dart';
import 'package:spark/src/features/chat/data/in_memory_chat_session_repository.dart';
import 'package:spark/src/features/papers/data/arxiv_seed_repository.dart';

void main() {
  for (final pdfAiEnabled in [false, true]) {
    testWidgets(
      'PDF AI entry is ${pdfAiEnabled ? 'shown' : 'hidden'} by its flag',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = InMemoryChatSessionRepository();
        final paper = const ArxivSeedRepository().getAll().first;
        await repository.save(paper.id, const [
          ChatMessage(fromUser: true, content: '解释这篇论文'),
        ]);

        await tester.pumpWidget(
          SparkApp(
            showSplash: false,
            config: AppConfig(
              environment: AppEnvironment.development,
              features: FeatureFlags(experimentalPdfAi: pdfAiEnabled),
            ),
            aiSessionRepository: repository,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('bottom-nav-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('ai-session-${paper.id}')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('paper-ai-fulltext-toggle')),
          pdfAiEnabled ? findsOneWidget : findsNothing,
        );
      },
    );
  }
}
