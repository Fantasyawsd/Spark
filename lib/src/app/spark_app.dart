import 'dart:async';

import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/navigation/spark_route_observer.dart';
import '../core/theme/spark_theme.dart';
import '../core/theme/theme_controller.dart';
import '../core/theme/theme_preference_repository.dart';
import '../features/chat/domain/chat_ai_service.dart';
import '../features/chat/domain/chat_session_repository.dart';
import '../features/papers/application/paper_translation_service.dart';
import '../features/papers/domain/paper_comment_repository.dart';
import '../features/papers/domain/paper_interaction_repository.dart';
import '../features/papers/domain/paper_link_service.dart';
import '../features/papers/domain/paper_preference_repository.dart';
import '../features/papers/domain/paper_reading_repository.dart';
import '../features/papers/domain/paper_share.dart';
import '../features/papers/domain/paper_translation.dart';
import '../features/search/domain/paper_search_history_repository.dart';
import 'spark_bootstrap.dart';
import 'spark_dependencies.dart';
import 'spark_shell.dart';

export 'spark_shell.dart' show SparkShell;

class SparkApp extends StatefulWidget {
  const SparkApp({
    super.key,
    this.config = const AppConfig.production(),
    this.showSplash = true,
    this.dependencies,
    this.commentRepository,
    this.interactionRepository,
    this.preferenceRepository,
    this.readingRepository,
    this.searchHistoryRepository,
    this.shareService,
    this.linkService,
    this.aiService,
    this.aiSessionRepository,
    this.translationServiceFactory,
    this.translationRepository,
    this.webSearchAiService,
  });

  final AppConfig config;
  final bool showSplash;
  final SparkDependencies? dependencies;
  final PaperCommentRepository? commentRepository;
  final PaperInteractionRepository? interactionRepository;
  final PaperPreferenceRepository? preferenceRepository;
  final PaperReadingRepository? readingRepository;
  final PaperSearchHistoryRepository? searchHistoryRepository;
  final PaperShareService? shareService;
  final PaperLinkService? linkService;
  final ChatAiService? aiService;
  final ChatSessionRepository? aiSessionRepository;
  final PaperTranslationServiceFactory? translationServiceFactory;
  final PaperTranslationRepository? translationRepository;
  final ChatAiService? webSearchAiService;

  @override
  State<SparkApp> createState() => _SparkAppState();
}

class _SparkAppState extends State<SparkApp> {
  late final SparkDependencies _dependencies;

  @override
  void initState() {
    super.initState();
    _dependencies = widget.dependencies ??
        SparkDependencies.preview(
          commentRepository: widget.commentRepository,
          interactionRepository: widget.interactionRepository,
          preferenceRepository: widget.preferenceRepository,
          readingRepository: widget.readingRepository,
          searchHistoryRepository: widget.searchHistoryRepository,
          shareService: widget.shareService,
          linkService: widget.linkService,
          aiService: widget.aiService,
          webSearchAiService: widget.webSearchAiService,
          aiSessionRepository: widget.aiSessionRepository,
          translationServiceFactory: widget.translationServiceFactory,
          translationRepository: widget.translationRepository,
        );
    unawaited(
      ThemeController.instance.configure(
        _dependencies.themePreferenceRepository,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) => MaterialApp(
        title: widget.config.applicationTitle,
        debugShowCheckedModeBanner: widget.config.showDebugBanner,
        theme: SparkTheme.light(),
        darkTheme: SparkTheme.dark(),
        themeMode: switch (ThemeController.instance.mode) {
          AppThemeMode.system => ThemeMode.system,
          AppThemeMode.light => ThemeMode.light,
          AppThemeMode.dark => ThemeMode.dark,
        },
        navigatorObservers: [SparkRouteObserver.instance],
        home: SparkBootstrap(
          showSplash: widget.showSplash,
          child: SparkShell(
            dependencies: _dependencies,
            features: widget.config.features,
          ),
        ),
      ),
    );
  }
}
