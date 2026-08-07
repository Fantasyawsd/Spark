import '../core/storage/local_json_store.dart';
import '../core/theme/file_theme_preference_repository.dart';
import '../core/theme/in_memory_theme_preference_repository.dart';
import '../core/theme/theme_preference_repository.dart';
import '../features/ai_settings/data/deepseek_api_credential_validator.dart';
import '../features/ai_settings/data/in_memory_deepseek_credential_repository.dart';
import '../features/ai_settings/data/secure_deepseek_credential_repository.dart';
import '../features/ai_settings/domain/deepseek_credential_repository.dart';
import '../features/chat/data/deepseek_chat_ai_service.dart';
import '../features/chat/data/deepseek_web_search_chat_ai_service.dart';
import '../features/chat/data/file_chat_session_repository.dart';
import '../features/chat/data/file_chat_session_settings_repository.dart';
import '../features/chat/data/in_memory_chat_session_repository.dart';
import '../features/chat/data/in_memory_chat_session_settings_repository.dart';
import '../features/chat/domain/chat_ai_service.dart';
import '../features/chat/domain/chat_session_repository.dart';
import '../features/chat/domain/chat_session_settings.dart';
import '../features/local_data/data/in_memory_local_data_repository.dart';
import '../features/local_data/data/json_local_data_repository.dart';
import '../features/local_data/domain/local_data_repository.dart';
import '../features/papers/application/paper_chat_context_loader.dart';
import '../features/papers/application/paper_translation_service.dart';
import '../features/papers/data/arxiv_seed_repository.dart';
import '../features/papers/data/cached_paper_pdf_content_provider.dart';
import '../features/papers/data/deepseek_paper_translation_service.dart';
import '../features/papers/data/file_paper_pdf_repository.dart';
import '../features/papers/data/file_paper_channel_preference_repository.dart';
import '../features/papers/data/file_paper_comment_repository.dart';
import '../features/papers/data/in_memory_paper_pdf_repository.dart';
import '../features/papers/data/file_paper_interaction_repository.dart';
import '../features/papers/data/paper_pdf_extraction_service.dart';
import '../features/papers/data/file_paper_keyword_repository.dart';
import '../features/papers/domain/paper_pdf_repository.dart';
import '../features/papers/domain/paper_pdf_content_provider.dart';
import '../features/papers/data/file_paper_preference_repository.dart';
import '../features/papers/data/file_paper_reading_repository.dart';
import '../features/papers/data/file_paper_translation_repository.dart';
import '../features/papers/data/cache/file_paper_cache_store.dart';
import '../features/papers/data/in_memory_paper_channel_preference_repository.dart';
import '../features/papers/data/in_memory_paper_comment_repository.dart';
import '../features/papers/data/in_memory_paper_interaction_repository.dart';
import '../features/papers/data/in_memory_paper_keyword_repository.dart';
import '../features/papers/data/in_memory_paper_preference_repository.dart';
import '../features/papers/data/in_memory_paper_reading_repository.dart';
import '../features/papers/data/in_memory_paper_translation_repository.dart';
import '../features/papers/data/offline_first_paper_catalog_repository.dart';
import '../features/papers/data/platform_paper_link_service.dart';
import '../features/papers/data/platform_paper_share_service.dart';
import '../features/papers/data/providers/arxiv/arxiv_atom_client.dart';
import '../features/papers/domain/paper_catalog.dart';
import '../features/papers/domain/paper_channel_preference_repository.dart';
import '../features/papers/domain/paper_comment_repository.dart';
import '../features/papers/domain/paper_interaction_repository.dart';
import '../features/papers/domain/paper_keyword_repository.dart';
import '../features/papers/domain/paper_link_service.dart';
import '../features/papers/domain/paper_preference_repository.dart';
import '../features/papers/domain/paper_reading_repository.dart';
import '../features/papers/domain/paper_share.dart';
import '../features/papers/domain/paper_translation.dart';
import '../features/papers/domain/paper_repository.dart';
import '../features/search/data/file_paper_search_history_repository.dart';
import '../features/search/data/in_memory_paper_search_history_repository.dart';
import '../features/search/domain/paper_search_history_repository.dart';

class SparkDependencies {
  const SparkDependencies({
    required this.paperRepository,
    this.paperCatalogRepository,
    required this.deepSeekCredentialRepository,
    this.deepSeekCredentialValidator,
    required this.commentRepository,
    required this.interactionRepository,
    required this.preferenceRepository,
    required this.channelPreferenceRepository,
    required this.readingRepository,
    required this.searchHistoryRepository,
    required this.shareService,
    required this.linkService,
    required this.aiService,
    required this.webSearchAiService,
    required this.aiSessionRepository,
    required this.chatSessionSettingsRepository,
    required this.translationServiceFactory,
    required this.translationRepository,
    required this.keywordRepository,
    required this.paperChatContextLoader,
    required this.mainAiService,
    required this.mainWebSearchAiService,
    required this.localDataRepository,
    required this.themePreferenceRepository,
  });

  factory SparkDependencies.production() {
    const seedRepository = ArxivSeedRepository();
    final credentialRepository = SecureDeepSeekCredentialRepository();
    final paperCacheStore = LocalJsonStore(
      fileName: 'paper_catalog_cache.json',
    );
    final commentStore = LocalJsonStore(fileName: 'paper_comments.json');
    final interactionStore = LocalJsonStore(
      fileName: 'paper_interactions.json',
    );
    final preferenceStore = LocalJsonStore(fileName: 'paper_preferences.json');
    final channelPreferenceStore = LocalJsonStore(
      fileName: 'paper_channel_preferences.json',
    );
    final readingStore = LocalJsonStore(fileName: 'paper_reading.json');
    final searchHistoryStore = LocalJsonStore(fileName: 'search_history.json');
    final aiSessionStore = LocalJsonStore(fileName: 'chat_sessions.json');
    final translationStore = LocalJsonStore(
      fileName: 'paper_translations.json',
    );
    final keywordStore = LocalJsonStore(fileName: 'paper_keywords.json');
    final pdfExtractStore = LocalJsonStore(
      fileName: 'paper_pdf_extracts.json',
    );
    final themeStore = LocalJsonStore(fileName: 'theme_preferences.json');
    final aiSessionSettingsStore = LocalJsonStore(
      fileName: 'chat_session_settings.json',
    );
    final keywordRepository = FilePaperKeywordRepository(store: keywordStore);
    final pdfRepository = FilePaperPdfRepository(store: pdfExtractStore);
    final pdfExtractionService = PaperPdfExtractionService();
    return SparkDependencies(
      paperRepository: seedRepository,
      paperCatalogRepository: OfflineFirstPaperCatalogRepository(
        remoteSource: ArxivAtomClient(),
        cacheStore: FilePaperCacheStore(store: paperCacheStore),
        seedRepository: seedRepository,
      ),
      deepSeekCredentialRepository: credentialRepository,
      deepSeekCredentialValidator: DeepSeekApiCredentialValidator(),
      commentRepository: FilePaperCommentRepository(store: commentStore),
      interactionRepository:
          FilePaperInteractionRepository(store: interactionStore),
      preferenceRepository:
          FilePaperPreferenceRepository(store: preferenceStore),
      channelPreferenceRepository: FilePaperChannelPreferenceRepository(
        store: channelPreferenceStore,
      ),
      readingRepository: FilePaperReadingRepository(store: readingStore),
      searchHistoryRepository:
          FilePaperSearchHistoryRepository(store: searchHistoryStore),
      shareService: const PlatformPaperShareService(),
      linkService: const PlatformPaperLinkService(),
      aiService: DeepSeekChatAiService(
        credentialRepository: credentialRepository,
      ),
      webSearchAiService: DeepSeekWebSearchChatAiService(
        credentialRepository: credentialRepository,
      ),
      aiSessionRepository: FileChatSessionRepository(store: aiSessionStore),
      chatSessionSettingsRepository: FileChatSessionSettingsRepository(
        store: aiSessionSettingsStore,
      ),
      translationServiceFactory: DeepSeekPaperTranslationServiceFactory(
        chatClientFactory: () => DeepSeekChatAiService(
          credentialRepository: credentialRepository,
          thinkingEnabled: false,
        ),
      ),
      translationRepository:
          FilePaperTranslationRepository(store: translationStore),
      keywordRepository: keywordRepository,
      paperChatContextLoader: PaperChatContextLoader(
        keywordRepository: keywordRepository,
        pdfContentProvider: CachedPaperPdfContentProvider(
          repository: pdfRepository,
          extractionService: pdfExtractionService,
        ),
      ),
      mainAiService: DeepSeekChatAiService(
        credentialRepository: credentialRepository,
      ),
      mainWebSearchAiService: DeepSeekWebSearchChatAiService(
        credentialRepository: credentialRepository,
      ),
      localDataRepository: JsonLocalDataRepository(
        paperCacheStores: [
          paperCacheStore,
          translationStore,
          keywordStore,
          pdfExtractStore,
        ],
        chatStores: [aiSessionStore, aiSessionSettingsStore],
        businessDataStores: [
          commentStore,
          interactionStore,
          preferenceStore,
          channelPreferenceStore,
          readingStore,
          searchHistoryStore,
          themeStore,
        ],
      ),
      themePreferenceRepository: FileThemePreferenceRepository(
        store: themeStore,
      ),
    );
  }

  factory SparkDependencies.preview({
    PaperRepository? paperRepository,
    PaperCatalogRepository? paperCatalogRepository,
    DeepSeekCredentialRepository? deepSeekCredentialRepository,
    DeepSeekCredentialValidator? deepSeekCredentialValidator,
    PaperCommentRepository? commentRepository,
    PaperInteractionRepository? interactionRepository,
    PaperPreferenceRepository? preferenceRepository,
    PaperChannelPreferenceRepository? channelPreferenceRepository,
    PaperReadingRepository? readingRepository,
    PaperSearchHistoryRepository? searchHistoryRepository,
    PaperShareService? shareService,
    PaperLinkService? linkService,
    ChatAiService? aiService,
    ChatAiService? webSearchAiService,
    ChatSessionRepository? aiSessionRepository,
    ChatSessionSettingsRepository? chatSessionSettingsRepository,
    PaperTranslationServiceFactory? translationServiceFactory,
    PaperTranslationRepository? translationRepository,
    PaperKeywordRepository? keywordRepository,
    PaperPdfRepository? pdfRepository,
    PaperPdfExtractionService? pdfExtractionService,
    PaperPdfContentProvider? pdfContentProvider,
    PaperChatContextLoader? paperChatContextLoader,
    ChatAiService? mainAiService,
    ChatAiService? mainWebSearchAiService,
    LocalDataRepository? localDataRepository,
    ThemePreferenceRepository? themePreferenceRepository,
  }) {
    final resolvedCredentialRepository =
        deepSeekCredentialRepository ?? InMemoryDeepSeekCredentialRepository();
    final resolvedAiService = aiService ??
        DeepSeekChatAiService(
          credentialRepository: resolvedCredentialRepository,
        );
    final resolvedWebSearchService = webSearchAiService ??
        DeepSeekWebSearchChatAiService(
          credentialRepository: resolvedCredentialRepository,
        );
    final resolvedKeywordRepository =
        keywordRepository ?? InMemoryPaperKeywordRepository();
    final resolvedPdfRepository = pdfRepository ?? InMemoryPaperPdfRepository();
    final resolvedPdfExtractionService =
        pdfExtractionService ?? PaperPdfExtractionService();
    final resolvedPdfContentProvider = pdfContentProvider ??
        CachedPaperPdfContentProvider(
          repository: resolvedPdfRepository,
          extractionService: resolvedPdfExtractionService,
        );
    return SparkDependencies(
      paperRepository: paperRepository ?? const ArxivSeedRepository(),
      paperCatalogRepository: paperCatalogRepository,
      deepSeekCredentialRepository: resolvedCredentialRepository,
      deepSeekCredentialValidator: deepSeekCredentialValidator,
      commentRepository: commentRepository ?? InMemoryPaperCommentRepository(),
      interactionRepository:
          interactionRepository ?? InMemoryPaperInteractionRepository(),
      preferenceRepository:
          preferenceRepository ?? InMemoryPaperPreferenceRepository(),
      channelPreferenceRepository: channelPreferenceRepository ??
          InMemoryPaperChannelPreferenceRepository(),
      readingRepository: readingRepository ?? InMemoryPaperReadingRepository(),
      searchHistoryRepository:
          searchHistoryRepository ?? InMemoryPaperSearchHistoryRepository(),
      shareService: shareService ?? const PlatformPaperShareService(),
      linkService: linkService ?? const PlatformPaperLinkService(),
      aiService: resolvedAiService,
      webSearchAiService: resolvedWebSearchService,
      aiSessionRepository:
          aiSessionRepository ?? InMemoryChatSessionRepository(),
      chatSessionSettingsRepository: chatSessionSettingsRepository ??
          InMemoryChatSessionSettingsRepository(),
      translationServiceFactory: translationServiceFactory ??
          DeepSeekPaperTranslationServiceFactory(
            chatClientFactory: () => DeepSeekChatAiService(
              credentialRepository: resolvedCredentialRepository,
              thinkingEnabled: false,
            ),
          ),
      translationRepository:
          translationRepository ?? InMemoryPaperTranslationRepository(),
      keywordRepository: resolvedKeywordRepository,
      paperChatContextLoader: paperChatContextLoader ??
          PaperChatContextLoader(
            keywordRepository: resolvedKeywordRepository,
            pdfContentProvider: resolvedPdfContentProvider,
          ),
      mainAiService: mainAiService ?? resolvedAiService,
      mainWebSearchAiService:
          mainWebSearchAiService ?? resolvedWebSearchService,
      localDataRepository: localDataRepository ?? InMemoryLocalDataRepository(),
      themePreferenceRepository:
          themePreferenceRepository ?? InMemoryThemePreferenceRepository(),
    );
  }

  final PaperRepository paperRepository;
  final PaperCatalogRepository? paperCatalogRepository;
  final DeepSeekCredentialRepository deepSeekCredentialRepository;
  final DeepSeekCredentialValidator? deepSeekCredentialValidator;
  final PaperCommentRepository commentRepository;
  final PaperInteractionRepository interactionRepository;
  final PaperPreferenceRepository preferenceRepository;
  final PaperChannelPreferenceRepository channelPreferenceRepository;
  final PaperReadingRepository readingRepository;
  final PaperSearchHistoryRepository searchHistoryRepository;
  final PaperShareService shareService;
  final PaperLinkService linkService;
  final ChatAiService aiService;
  final ChatAiService webSearchAiService;
  final ChatSessionRepository aiSessionRepository;
  final ChatSessionSettingsRepository chatSessionSettingsRepository;
  final PaperTranslationServiceFactory translationServiceFactory;
  final PaperTranslationRepository translationRepository;
  final PaperKeywordRepository keywordRepository;
  final PaperChatContextLoader paperChatContextLoader;
  final ChatAiService mainAiService;
  final ChatAiService mainWebSearchAiService;
  final LocalDataRepository localDataRepository;
  final ThemePreferenceRepository themePreferenceRepository;
}
