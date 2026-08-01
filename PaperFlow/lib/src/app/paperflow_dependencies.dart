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
import '../features/papers/data/in_memory_paper_ai_session_repository.dart';
import '../features/papers/data/in_memory_paper_comment_repository.dart';
import '../features/papers/data/in_memory_paper_interaction_repository.dart';
import '../features/papers/data/in_memory_paper_preference_repository.dart';
import '../features/papers/data/in_memory_paper_reading_repository.dart';
import '../features/papers/data/in_memory_paper_translation_repository.dart';
import '../features/papers/data/platform_paper_share_service.dart';
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
    return PaperFlowDependencies(
      paperRepository: const ArxivSeedRepository(),
      commentRepository: FilePaperCommentRepository(),
      interactionRepository: FilePaperInteractionRepository(),
      preferenceRepository: FilePaperPreferenceRepository(),
      readingRepository: FilePaperReadingRepository(),
      searchHistoryRepository: FilePaperSearchHistoryRepository(),
      shareService: const PlatformPaperShareService(),
      linkService: const PlatformPaperLinkService(),
      aiService: DeepSeekPaperAiService(),
      webSearchAiService: DeepSeekWebSearchAiService(),
      aiSessionRepository: FilePaperAiSessionRepository(),
      translationServiceFactory: const DeepSeekPaperTranslationServiceFactory(),
      translationRepository: FilePaperTranslationRepository(),
      mainAiService: DeepSeekPaperAiService(),
      mainWebSearchAiService: DeepSeekWebSearchAiService(),
    );
  }

  factory PaperFlowDependencies.preview({
    PaperRepository? paperRepository,
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
    final resolvedAiService = aiService ?? DeepSeekPaperAiService();
    final resolvedWebSearchService =
        webSearchAiService ?? DeepSeekWebSearchAiService();
    return PaperFlowDependencies(
      paperRepository: paperRepository ?? const ArxivSeedRepository(),
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
          const DeepSeekPaperTranslationServiceFactory(),
      translationRepository:
          translationRepository ?? InMemoryPaperTranslationRepository(),
      mainAiService: mainAiService ?? resolvedAiService,
      mainWebSearchAiService:
          mainWebSearchAiService ?? resolvedWebSearchService,
    );
  }

  final PaperRepository paperRepository;
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
