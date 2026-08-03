import '../features/ai_settings/data/deepseek_api_credential_validator.dart';
import '../features/ai_settings/data/in_memory_deepseek_credential_repository.dart';
import '../features/ai_settings/data/secure_deepseek_credential_repository.dart';
import '../features/ai_settings/domain/deepseek_credential_repository.dart';
import '../core/storage/local_json_store.dart';
import '../core/theme/file_theme_preference_repository.dart';
import '../core/theme/in_memory_theme_preference_repository.dart';
import '../core/theme/theme_preference_repository.dart';
import '../features/local_data/data/in_memory_local_data_repository.dart';
import '../features/local_data/data/json_local_data_repository.dart';
import '../features/local_data/domain/local_data_repository.dart';
import '../features/papers/application/paper_ai_service.dart';
import '../features/papers/application/paper_ai_session_repository.dart';
import '../features/papers/application/paper_link_service.dart';
import '../features/papers/application/paper_share_service.dart';
import '../features/papers/application/paper_translation_service.dart';
import '../features/papers/data/arxiv_seed_repository.dart';
import '../features/papers/data/deepseek_paper_ai_service.dart';
import '../features/papers/data/deepseek_paper_translation_service.dart';
import '../features/papers/data/deepseek_web_search_ai_service.dart';
import '../features/papers/data/file_paper_ai_session_repository.dart';
import '../features/papers/data/file_paper_channel_preference_repository.dart';
import '../features/papers/data/file_paper_comment_repository.dart';
import '../features/papers/data/file_paper_interaction_repository.dart';
import '../features/papers/data/file_paper_preference_repository.dart';
import '../features/papers/data/file_paper_reading_repository.dart';
import '../features/papers/data/file_paper_translation_repository.dart';
import '../features/papers/data/cache/file_paper_cache_store.dart';
import '../features/papers/data/in_memory_paper_ai_session_repository.dart';
import '../features/papers/data/in_memory_paper_channel_preference_repository.dart';
import '../features/papers/data/in_memory_paper_comment_repository.dart';
import '../features/papers/data/in_memory_paper_interaction_repository.dart';
import '../features/papers/data/in_memory_paper_preference_repository.dart';
import '../features/papers/data/in_memory_paper_reading_repository.dart';
import '../features/papers/data/in_memory_paper_translation_repository.dart';
import '../features/papers/data/platform_paper_share_service.dart';
import '../features/papers/data/offline_first_paper_catalog_repository.dart';
import '../features/papers/data/providers/arxiv/arxiv_atom_client.dart';
import '../features/papers/domain/paper_catalog.dart';
import '../features/papers/domain/paper_channel_preference_repository.dart';
import '../features/papers/domain/paper_comment_repository.dart';
import '../features/papers/domain/paper_interaction_repository.dart';
import '../features/papers/domain/paper_preference_repository.dart';
import '../features/papers/domain/paper_reading_repository.dart';
import '../features/papers/domain/paper_repository.dart';
import '../features/search/data/file_paper_search_history_repository.dart';
import '../features/search/data/in_memory_paper_search_history_repository.dart';
import '../features/search/domain/paper_search_history_repository.dart';

class PaperFlowDependencies {
  const PaperFlowDependencies({
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
    required this.translationServiceFactory,
    required this.translationRepository,
    required this.mainAiService,
    required this.mainWebSearchAiService,
    required this.localDataRepository,
    required this.themePreferenceRepository,
  });

  factory PaperFlowDependencies.production() {
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
    final aiSessionStore = LocalJsonStore(fileName: 'paper_ai_sessions.json');
    final translationStore = LocalJsonStore(
      fileName: 'paper_translations.json',
    );
    final themeStore = LocalJsonStore(fileName: 'theme_preferences.json');
    return PaperFlowDependencies(
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
      aiService: DeepSeekPaperAiService(
        credentialRepository: credentialRepository,
      ),
      webSearchAiService: DeepSeekWebSearchAiService(
        credentialRepository: credentialRepository,
      ),
      aiSessionRepository: FilePaperAiSessionRepository(store: aiSessionStore),
      translationServiceFactory: DeepSeekPaperTranslationServiceFactory(
        credentialRepository: credentialRepository,
      ),
      translationRepository:
          FilePaperTranslationRepository(store: translationStore),
      mainAiService: DeepSeekPaperAiService(
        credentialRepository: credentialRepository,
      ),
      mainWebSearchAiService: DeepSeekWebSearchAiService(
        credentialRepository: credentialRepository,
      ),
      localDataRepository: JsonLocalDataRepository(
        paperCacheStores: [paperCacheStore, translationStore],
        chatStores: [aiSessionStore],
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

  factory PaperFlowDependencies.preview({
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
    PaperAiService? aiService,
    PaperAiService? webSearchAiService,
    PaperAiSessionRepository? aiSessionRepository,
    PaperTranslationServiceFactory? translationServiceFactory,
    PaperTranslationRepository? translationRepository,
    PaperAiService? mainAiService,
    PaperAiService? mainWebSearchAiService,
    LocalDataRepository? localDataRepository,
    ThemePreferenceRepository? themePreferenceRepository,
  }) {
    final resolvedCredentialRepository =
        deepSeekCredentialRepository ?? InMemoryDeepSeekCredentialRepository();
    final resolvedAiService = aiService ??
        DeepSeekPaperAiService(
          credentialRepository: resolvedCredentialRepository,
        );
    final resolvedWebSearchService = webSearchAiService ??
        DeepSeekWebSearchAiService(
          credentialRepository: resolvedCredentialRepository,
        );
    return PaperFlowDependencies(
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
          aiSessionRepository ?? InMemoryPaperAiSessionRepository(),
      translationServiceFactory: translationServiceFactory ??
          DeepSeekPaperTranslationServiceFactory(
            credentialRepository: resolvedCredentialRepository,
          ),
      translationRepository:
          translationRepository ?? InMemoryPaperTranslationRepository(),
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
  final PaperAiService aiService;
  final PaperAiService webSearchAiService;
  final PaperAiSessionRepository aiSessionRepository;
  final PaperTranslationServiceFactory translationServiceFactory;
  final PaperTranslationRepository translationRepository;
  final PaperAiService mainAiService;
  final PaperAiService mainWebSearchAiService;
  final LocalDataRepository localDataRepository;
  final ThemePreferenceRepository themePreferenceRepository;
}
