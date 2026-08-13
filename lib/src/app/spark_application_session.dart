import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/theme/theme_controller.dart';
import '../features/ai_settings/application/deepseek_credential_controller.dart';
import '../features/chat/application/chat_conversation_coordinator.dart';
import '../features/chat/application/chat_session_controller.dart';
import '../features/chat/application/main_ai_chat_definition.dart';
import '../features/chat/domain/chat_ai_service.dart';
import '../features/chat/domain/chat_session_repository.dart';
import '../features/local_data/application/local_data_controller.dart';
import '../features/local_data/domain/local_data_repository.dart';
import '../features/papers/application/paper_chat_context_loader.dart';
import '../features/papers/application/paper_comment_controller.dart';
import '../features/papers/application/paper_controller.dart';
import '../features/papers/application/paper_reading_controller.dart';
import '../features/papers/application/paper_translation_service.dart';
import '../features/papers/domain/paper.dart';
import '../features/papers/domain/paper_link_service.dart';
import '../features/search/domain/paper_search_history_repository.dart';
import 'spark_dependencies.dart';

/// Owns the controllers and cross-controller coordination that live for the
/// entire application shell session.
class SparkApplicationSession extends ChangeNotifier {
  SparkApplicationSession(this.dependencies) {
    paperController = PaperController(
      dependencies.paperRepository,
      interactionRepository: dependencies.interactionRepository,
      preferenceRepository: dependencies.preferenceRepository,
      catalogRepository: dependencies.paperCatalogRepository,
      readPaperIdsProvider: () => readingController.readPaperIds,
    )..addListener(_handlePaperStateChanged);
    readingController = PaperReadingController(
      repository: dependencies.readingRepository,
    )..addListener(_handleReadingStateChanged);
    commentController = PaperCommentController(
      repository: dependencies.commentRepository,
    );
    paperAiService = dependencies.aiService;
    webSearchAiService = dependencies.webSearchAiService;
    mainAiService = dependencies.mainAiService;
    mainWebSearchAiService = dependencies.mainWebSearchAiService;
    aiSessionRepository = dependencies.aiSessionRepository;
    chatConversationCoordinator = ChatConversationCoordinator(
      sessionRepository: aiSessionRepository,
      settingsRepository: dependencies.chatSessionSettingsRepository,
    );
    chatSessionController = ChatSessionController(
      repository: aiSessionRepository,
      settingsRepository: dependencies.chatSessionSettingsRepository,
      mainSessionId: MainAiChatDefinition.sessionId,
      contexts: _paperChatContexts,
      beforeDelete: chatConversationCoordinator.remove,
    );
    translationServiceFactory = dependencies.translationServiceFactory;
    paperChatContextLoader = dependencies.paperChatContextLoader;
    searchHistoryRepository = dependencies.searchHistoryRepository;
    linkService = dependencies.linkService;
    credentialController = DeepSeekCredentialController(
      repository: dependencies.deepSeekCredentialRepository,
      validator: dependencies.deepSeekCredentialValidator,
    );
    localDataController = LocalDataController(
      repository: dependencies.localDataRepository,
      beforeClear: _prepareLocalDataMutation,
      afterClear: _reloadAfterLocalDataMutation,
    );
  }

  final SparkDependencies dependencies;

  late final PaperController paperController;
  late final PaperCommentController commentController;
  late final PaperReadingController readingController;
  late final ChatAiService paperAiService;
  late final ChatAiService webSearchAiService;
  late final ChatAiService mainAiService;
  late final ChatAiService mainWebSearchAiService;
  late final ChatSessionRepository aiSessionRepository;
  late final ChatSessionController chatSessionController;
  late final ChatConversationCoordinator chatConversationCoordinator;
  late final PaperSearchHistoryRepository searchHistoryRepository;
  late final PaperTranslationServiceFactory translationServiceFactory;
  late final PaperChatContextLoader paperChatContextLoader;
  late final PaperLinkService linkService;
  late final DeepSeekCredentialController credentialController;
  late final LocalDataController localDataController;

  bool _initializationStarted = false;
  bool _disposed = false;

  void initialize() {
    if (_initializationStarted || _disposed) return;
    _initializationStarted = true;

    unawaited(readingController.initialize());
    unawaited(chatSessionController.refresh());
    unawaited(credentialController.initialize());
    unawaited(localDataController.initialize());
    unawaited(_initializePaperState());
  }

  List<Paper> papersForIds(Iterable<String> ids) {
    final papersById = {
      for (final paper in paperController.feed.allPapers) paper.id: paper,
    };
    return ids
        .map((id) => papersById[id])
        .whereType<Paper>()
        .toList(growable: false);
  }

  Map<String, List<Paper>> get favoritePapersByGroup => {
        for (final group in paperController.interactions.favoriteGroups)
          group.id: papersForIds(
            paperController.interactions.favoritePaperIds(group.id),
          ),
      };

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    paperController
      ..removeListener(_handlePaperStateChanged)
      ..dispose();
    commentController.dispose();
    readingController
      ..removeListener(_handleReadingStateChanged)
      ..dispose();
    chatConversationCoordinator.dispose();
    chatSessionController.dispose();
    credentialController.dispose();
    localDataController.dispose();
    super.dispose();
  }

  Iterable<ChatContextSummary> get _paperChatContexts =>
      paperController.feed.allPapers
          .map((paper) => ChatContextSummary(id: paper.id, title: paper.title));

  void _handlePaperStateChanged() {
    if (_disposed) return;
    chatSessionController.updateContexts(_paperChatContexts);
    notifyListeners();
  }

  void _handleReadingStateChanged() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _initializePaperState() async {
    await paperController.initialize();
    if (_disposed) return;
    await commentController.initialize(
      paperController.feed.allPapers.map((paper) => paper.id),
    );
    if (_disposed) return;
    chatSessionController.updateContexts(_paperChatContexts);
  }

  Future<void> _prepareLocalDataMutation(LocalDataClearTarget target) async {
    if (target == LocalDataClearTarget.chats ||
        target == LocalDataClearTarget.allBusinessData) {
      await chatConversationCoordinator.removeAll();
    }
    await Future.wait([
      paperController.interactions.flushPendingWrites(),
      paperController.feed.flushPreferenceWrites(),
      paperController.feed.flushCatalogOperations(),
      commentController.flushPendingWrites(),
      readingController.flushPendingWrites(),
      ThemeController.instance.flushPendingWrites(),
    ]);
  }

  Future<void> _reloadAfterLocalDataMutation(
    LocalDataClearTarget target,
  ) async {
    switch (target) {
      case LocalDataClearTarget.paperCache:
        return;
      case LocalDataClearTarget.chats:
        await chatSessionController.reload();
        return;
      case LocalDataClearTarget.allBusinessData:
        await Future.wait([
          paperController.reloadLocalState(),
          readingController.reload(),
          commentController.reload(
            paperController.feed.allPapers.map((paper) => paper.id),
          ),
          chatSessionController.reload(),
          ThemeController.instance.reload(),
        ]);
        return;
    }
  }
}
