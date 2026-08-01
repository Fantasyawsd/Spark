import '../features/ai_settings/data/deepseek_api_credential_validator.dart';
import '../features/ai_settings/data/in_memory_deepseek_credential_repository.dart';
import '../features/ai_settings/data/secure_deepseek_credential_repository.dart';
import '../features/ai_settings/domain/deepseek_credential_repository.dart';
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
import '../features/papers/data/file_paper_comment_repository.dart';
import '../features/papers/data/file_paper_interaction_repository.dart';
import '../features/papers/data/file_paper_preference_repository.dart';
import '../features/papers/data/file_paper_reading_repository.dart';
import '../features/papers/data/file_paper_translation_repository.dart';
import '../features/papers/data/cache/file_paper_cache_store.dart';
import '../features/papers/data/in_memory_paper_ai_session_repository.dart';
import '../features/papers/data/in_memory_paper_comment_repository.dart';
import '../features/papers/data/in_memory_paper_interaction_repository.dart';
import '../features/papers/data/in_memory_paper_preference_repository.dart';
import '../features/papers/data/in_memory_paper_reading_repository.dart';
import '../features/papers/data/in_memory_paper_translation_repository.dart';
import '../features/papers/data/platform_paper_share_service.dart';
import '../features/papers/data/offline_first_paper_catalog_repository.dart';
import '../features/papers/data/providers/arxiv/arxiv_atom_client.dart';
import '../features/papers/domain/paper_catalog.dart';
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
  });

  factory PaperFlowDependencies.production() {
    const seedRepository = ArxivSeedRepository();
    final credentialRepository = SecureDeepSeekCredentialRepository();
    return PaperFlowDependencies(
      paperRepository: seedRepository,
      paperCatalogRepository: OfflineFirstPaperCatalogRepository(
        remoteSource: ArxivAtomClient(),
        cacheStore: FilePaperCacheStore(),
        seedRepository: seedRepository,
      ),
      deepSeekCredentialRepository: credentialRepository,
      deepSeekCredentialValidator: DeepSeekApiCredentialValidator(),
      commentRepository: FilePaperCommentRepository(),
      interactionRepository: FilePaperInteractionRepository(),
      preferenceRepository: FilePaperPreferenceRepository(),
      readingRepository: FilePaperReadingRepository(),
      searchHistoryRepository: FilePaperSearchHistoryRepository(),
      shareService: const PlatformPaperShareService(),
      linkService: const PlatformPaperLinkService(),
      aiService: DeepSeekPaperAiService(
        credentialRepository: credentialRepository,
      ),
      webSearchAiService: DeepSeekWebSearchAiService(
        credentialRepository: credentialRepository,
      ),
      aiSessionRepository: FilePaperAiSessionRepository(),
      translationServiceFactory: DeepSeekPaperTranslationServiceFactory(
        credentialRepository: credentialRepository,
      ),
      translationRepository: FilePaperTranslationRepository(),
      mainAiService: DeepSeekPaperAiService(
        credentialRepository: credentialRepository,
      ),
      mainWebSearchAiService: DeepSeekWebSearchAiService(
        credentialRepository: credentialRepository,
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
    );
  }

  final PaperRepository paperRepository;
  final PaperCatalogRepository? paperCatalogRepository;
  final DeepSeekCredentialRepository deepSeekCredentialRepository;
  final DeepSeekCredentialValidator? deepSeekCredentialValidator;
  final PaperCommentRepository commentRepository;
  final PaperInteractionRepository interactionRepository;
  final PaperPreferenceRepository preferenceRepository;
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
}
