import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/spark.dart';
import 'package:spark/src/features/papers/presentation/widgets/paper_grid_card.dart';

void main() {
  Future<void> pumpCard(WidgetTester tester, Paper paper) async {
    final palette = SparkTheme.light();
    await tester.pumpWidget(
      MaterialApp(
        theme: palette,
        home: Scaffold(
          body: Center(
            child: PaperGridCard(
              paper: paper,
              index: 0,
              liked: false,
              saved: false,
              onOpen: () {},
              onLike: () {},
              onSave: () {},
              onSaveLongPress: () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders trending chip when webTrendReason is present', (
    tester,
  ) async {
    final paper = Paper(
      id: 'trend-1',
      title: 'A trending paper title',
      authors: const ['Researcher'],
      abstractText: 'Abstract text.',
      chineseAbstractMarkdown: '',
      readMinutes: 3,
      webTrendReason: 'powerful result',
      webTrendTopics: const ['topic-a', 'topic-b'],
      publishedAt: DateTime.utc(2026, 1, 1),
    );

    await pumpCard(tester, paper);

    expect(find.text('Trending · powerful result'), findsOneWidget);
  });

  testWidgets('truncates long webTrendReason to 24 characters', (tester) async {
    final paper = Paper(
      id: 'trend-long',
      title: 'A trending paper title',
      authors: const ['Researcher'],
      abstractText: 'Abstract text.',
      chineseAbstractMarkdown: '',
      readMinutes: 3,
      webTrendReason: 'a very long trending reason that should be truncated',
      webTrendTopics: const ['topic-a'],
      publishedAt: DateTime.utc(2026, 1, 1),
    );

    await pumpCard(tester, paper);

    expect(find.text('Trending · a very long trending rea…'), findsOneWidget);
  });

  testWidgets('does not render trending chip when webTrendReason is null', (
    tester,
  ) async {
    final paper = Paper(
      id: 'no-trend',
      title: 'A plain paper title',
      authors: const ['Researcher'],
      subjects: const ['cs.AI'],
      abstractText: 'Abstract text.',
      chineseAbstractMarkdown: '',
      readMinutes: 3,
      publishedAt: DateTime.utc(2026, 1, 1),
    );

    await pumpCard(tester, paper);

    expect(find.textContaining('Trending'), findsNothing);
  });
}
