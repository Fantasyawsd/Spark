import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/spark.dart';
import 'package:spark/src/core/theme/in_memory_theme_preference_repository.dart';
import 'package:spark/src/features/chat/presentation/widgets/paper_ai_chat_app_bar.dart';
import 'package:spark/src/features/chat/presentation/paper_ai_chat_screen.dart';
import 'package:spark/src/features/chat/data/in_memory_chat_session_repository.dart';
import 'package:spark/src/features/papers/presentation/widgets/paper_discovery_card.dart';
import 'package:spark/src/features/papers/presentation/widgets/papers_header.dart';

import 'support/paper_ember_test_navigation.dart';
import 'support/paper_presentation_test_support.dart';

const _capture = bool.fromEnvironment('SPARK_CAPTURE_UI');

void main() {
  test('new profiles default to ember and saved accents are preserved',
      () async {
    final controller = ThemeController();
    addTearDown(controller.dispose);
    await controller.configure(InMemoryThemePreferenceRepository());
    expect(controller.color, SparkThemeColor.orange);
    for (final accent in SparkThemeColor.values) {
      await controller.configure(InMemoryThemePreferenceRepository(accent));
      expect(controller.color, accent);
    }
  });

  test('reading text and filled controls keep accessible contrast', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance();
      final y = b.computeLuminance();
      return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
    }

    for (final accent in SparkThemeColor.values) {
      for (final palette in [
        SparkPalette.light(accent),
        SparkPalette.dark(accent)
      ]) {
        expect(contrast(palette.ink, palette.card), greaterThanOrEqualTo(7));
        expect(
            contrast(palette.muted, palette.card), greaterThanOrEqualTo(4.5));
        expect(contrast(palette.actionBackground, palette.onAction),
            greaterThanOrEqualTo(4.5));
        expect(contrast(palette.primary, palette.onPrimary),
            greaterThanOrEqualTo(4.5));
      }
    }
  });

  for (final scale in [1.0, 1.6]) {
    testWidgets('discovery controls fit a narrow screen at scale $scale',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final actions = <String>[];
      await tester.pumpWidget(MaterialApp(
        theme: SparkTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(
              size: const Size(320, 720), textScaler: TextScaler.linear(scale)),
          child: Scaffold(
              body: Column(children: [
            PapersHeader(
              channels: const ['推荐', '关注', '最新', '机器学习'],
              selectedIndex: 0,
              onChannelSelected: (index) => actions.add('channel-$index'),
              onManageChannels: () => actions.add('manage'),
              onSearch: () => actions.add('search'),
              timeRangeLabel: '最近一周',
              onSelectTimeRange: () => actions.add('filter'),
              gridMode: false,
              onToggleViewMode: () => actions.add('view'),
            ),
            Expanded(
                child: PaperDiscoveryCard(
              paper: _paper(),
              saved: false,
              readLater: false,
              onOpen: () => actions.add('open'),
              onSave: () => actions.add('save'),
              onSaveLongPress: () => actions.add('group'),
              onReadLater: () => actions.add('later'),
            )),
          ])),
        ),
      ));
      await tester.tap(find.byTooltip('搜索'));
      await tester.tap(find.byKey(const ValueKey('paper-time-filter')));
      await tester.tap(find.byKey(const ValueKey('paper-channel-manage')));
      await tester.tap(find.byKey(const ValueKey('papers-view-mode-toggle')));
      await tester
          .tap(find.byKey(const ValueKey('paper-discovery-open-review')));
      await tester
          .tap(find.byKey(const ValueKey('paper-discovery-later-review')));
      await tester
          .longPress(find.byKey(const ValueKey('paper-discovery-save-review')));
      await tester.pumpAndSettle();
      expect(actions,
          ['search', 'filter', 'manage', 'view', 'open', 'later', 'group']);
      expect(find.text('中文摘要尚未生成。'), findsNothing);
      expect(find.textContaining('Trending'), findsNothing);
      expect(find.textContaining('被引'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('paper context distinguishes capability, loading and loaded',
      (tester) async {
    final load = Completer<ChatContext>();
    const context =
        ChatContext(id: 'review', title: 'Paper title', systemPrompt: '');
    await tester.pumpWidget(MaterialApp(
      theme: SparkTheme.dark(),
      home: Scaffold(
          appBar: PaperAiChatAppBar(
        initialTitle: 'ChatPaper',
        subtitle: 'Paper title',
        showPaperContext: true,
        fullTextAvailable: true,
        onLoadFullText: () => load.future,
        onApplyFullText: (value) => value.id == 'review',
        previewMode: false,
        onPreviewModeChanged: (_) {},
        onOpenSettings: () {},
        selectionActive: false,
        selectionCount: 0,
        onCancelSelection: () {},
      )),
    ));
    expect(find.text('基于论文摘要'), findsOneWidget);
    expect(find.text('已读取全文'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('paper-ai-fulltext-toggle')));
    await tester.pump();
    expect(find.text('正在读取全文…'), findsOneWidget);
    load.complete(context);
    await tester.pumpAndSettle();
    expect(find.text('已读取全文'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'production reader exposes four sections and safe small-screen layout',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SparkApp(
      showSplash: false,
      dependencies: SparkDependencies.preview(
        translationServiceFactory: const FakePaperTranslationServiceFactory(),
      ),
    ));
    await tester.pumpAndSettle();
    await openFirstDiscoveredPaper(tester);
    final tabs = tester.widget<SparkSegmentedControl>(
        find.byKey(const ValueKey('paper-tabs')));
    expect(tabs.tabs, ['概览', '解读', '相关', '详情']);
    expect(find.byKey(const ValueKey('paper-action-save')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('paper-action-read-later')), findsOneWidget);
    expect(find.byKey(const ValueKey('paper-ai-entry')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('capture implemented light and dark screens', (tester) async {
    if (!_capture) return;
    await tester.runAsync(_loadReviewFonts);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final boundary = GlobalKey();
    final theme = ThemeController();
    addTearDown(theme.dispose);
    final dependencies = SparkDependencies.preview(
      themeController: theme,
      themePreferenceRepository: InMemoryThemePreferenceRepository(),
      translationServiceFactory: const FakePaperTranslationServiceFactory(),
    );
    await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: SparkApp(showSplash: false, dependencies: dependencies)));
    await tester.pumpAndSettle();
    await _captureScreen(tester, boundary, 'discovery');
    await openFirstDiscoveredPaper(tester);
    await _captureScreen(tester, boundary, 'reader');
    theme.setMode(AppThemeMode.dark);
    await tester.pumpAndSettle();
    await _captureScreen(tester, boundary, 'reader-dark');
    theme.setMode(AppThemeMode.light);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paper-detail-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bottom-nav-2')));
    await tester.pumpAndSettle();
    await _captureScreen(tester, boundary, 'library');
    await tester.pumpWidget(RepaintBoundary(
      key: boundary,
      child: MaterialApp(
        theme: SparkTheme.light(),
        home: PaperAiChatScreen(
          chatContext: const ChatContext(
            id: 'review-paper',
            title:
                'Corruption Robust Offline Reinforcement Learning with Human Feedback',
            systemPrompt: '',
          ),
          aiService: const FakeChatAiService(),
          sessionRepository: InMemoryChatSessionRepository(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await _captureScreen(tester, boundary, 'chat');
    expect(tester.takeException(), isNull);
  });
}

Paper _paper() => Paper(
      id: 'review',
      title: 'A long paper title for checking readable discovery previews',
      authors: const ['Researcher'],
      abstractText:
          'An abstract with enough content to check readable line lengths. ' *
              12,
      chineseAbstractMarkdown: '中文摘要尚未生成。',
      readMinutes: 4,
    );

Future<void> _loadReviewFonts() async {
  final fonts = {
    'Roboto': '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    'Arial': '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    'Microsoft YaHei': '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    'PingFang SC': '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    'MaterialIcons':
        '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    'Noto Sans CJK SC':
        '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    'serif': '/usr/share/fonts/opentype/noto/NotoSerifCJK-Regular.ttc',
    'Noto Serif CJK SC':
        '/usr/share/fonts/opentype/noto/NotoSerifCJK-Regular.ttc',
  };
  for (final entry in fonts.entries) {
    final file = File(entry.value);
    if (!file.existsSync()) {
      throw StateError('Review font is missing: ${entry.key}');
    }
    final loader = FontLoader(entry.key);
    loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    await loader.load();
  }
}

Future<void> _captureScreen(
    WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    final directory = Directory('build/ui-review')..createSync(recursive: true);
    File('${directory.path}/$name.png')
        .writeAsBytesSync(bytes.buffer.asUint8List());
    image.dispose();
  });
}
