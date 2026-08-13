import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/app/spark_dependencies.dart';
import 'package:spark/src/core/config/app_config.dart';
import 'package:spark/src/core/config/app_environment.dart';
import 'package:spark/src/core/config/feature_flags.dart';
import 'package:spark/src/features/ai_settings/data/secure_deepseek_credential_repository.dart';
import 'package:spark/src/core/theme/file_theme_preference_repository.dart';
import 'package:spark/src/core/theme/theme_controller.dart';
import 'package:spark/src/features/chat/chat.dart';
import 'package:spark/src/features/chat/data/deepseek_chat_ai_service.dart';
import 'package:spark/src/features/chat/data/deepseek_web_search_chat_ai_service.dart';
import 'package:spark/src/features/chat/data/file_chat_session_repository.dart';
import 'package:spark/src/features/papers/domain/paper.dart';
import 'package:spark/src/features/papers/domain/paper_repository.dart';
import 'package:spark/src/features/papers/data/arxiv_seed_repository.dart';
import 'package:spark/src/features/papers/data/file_paper_comment_repository.dart';
import 'package:spark/src/features/papers/data/file_paper_interaction_repository.dart';
import 'package:spark/src/features/papers/data/file_paper_preference_repository.dart';
import 'package:spark/src/features/papers/data/file_paper_reading_repository.dart';
import 'package:spark/src/features/papers/data/file_paper_translation_repository.dart';
import 'package:spark/src/features/papers/data/platform_paper_share_service.dart';
import 'package:spark/src/features/papers/data/offline_first_paper_catalog_repository.dart';
import 'package:spark/src/features/papers/data/paper_api_catalog_repository.dart';

void main() {
  test('production dependencies compose concrete infrastructure once', () {
    final dependencies = SparkDependencies.production();

    expect(dependencies.paperRepository, isA<ArxivSeedRepository>());
    expect(
      dependencies.paperCatalogRepository,
      isA<OfflineFirstPaperCatalogRepository>(),
    );
    expect(
      dependencies.deepSeekCredentialRepository,
      isA<SecureDeepSeekCredentialRepository>(),
    );
    expect(dependencies.commentRepository, isA<FilePaperCommentRepository>());
    expect(
      dependencies.interactionRepository,
      isA<FilePaperInteractionRepository>(),
    );
    expect(
      dependencies.preferenceRepository,
      isA<FilePaperPreferenceRepository>(),
    );
    expect(dependencies.readingRepository, isA<FilePaperReadingRepository>());
    expect(dependencies.shareService, isA<PlatformPaperShareService>());
    expect(dependencies.aiService, isA<DeepSeekChatAiService>());
    expect(
      dependencies.webSearchAiService,
      isA<DeepSeekWebSearchChatAiService>(),
    );
    expect(dependencies.aiSessionRepository, isA<FileChatSessionRepository>());
    expect(
      dependencies.translationRepository,
      isA<FilePaperTranslationRepository>(),
    );
    expect(dependencies.mainAiService, isA<DeepSeekChatAiService>());
    expect(
      dependencies.mainWebSearchAiService,
      isA<DeepSeekWebSearchChatAiService>(),
    );
    expect(
      dependencies.themePreferenceRepository,
      isA<FileThemePreferenceRepository>(),
    );
  });

  test('development config composes Paper API over the existing fallback', () {
    const config = AppConfig(
      environment: AppEnvironment.development,
      features: FeatureFlags(),
      paperApiBaseUrl: 'http://127.0.0.1:8000/api/v1',
    );

    final dependencies = SparkDependencies.forConfig(config);

    expect(
      dependencies.paperCatalogRepository,
      isA<PaperApiCatalogRepository>(),
    );
  });

  test(
    'preview dependencies preserve overrides and default main chat wiring',
    () {
      final paperRepository = _FakePaperRepository();
      final aiService = _FakeAiService();
      final webSearchAiService = _FakeAiService();

      final dependencies = SparkDependencies.preview(
        paperRepository: paperRepository,
        aiService: aiService,
        webSearchAiService: webSearchAiService,
      );

      expect(dependencies.paperRepository, same(paperRepository));
      expect(dependencies.aiService, same(aiService));
      expect(dependencies.webSearchAiService, same(webSearchAiService));
      expect(dependencies.mainAiService, same(aiService));
      expect(dependencies.mainWebSearchAiService, same(webSearchAiService));
    },
  );

  test('preview dependencies allow separate main chat services', () {
    final paperAiService = _FakeAiService();
    final mainAiService = _FakeAiService();

    final dependencies = SparkDependencies.preview(
      aiService: paperAiService,
      mainAiService: mainAiService,
    );

    expect(dependencies.aiService, same(paperAiService));
    expect(dependencies.mainAiService, same(mainAiService));
  });

  test('preview dependencies isolate and preserve theme controllers', () {
    final injected = ThemeController();
    final overridden = SparkDependencies.preview(themeController: injected);
    final firstDefault = SparkDependencies.preview();
    final secondDefault = SparkDependencies.preview();

    expect(overridden.themeController, same(injected));
    expect(firstDefault.themeController,
        isNot(same(secondDefault.themeController)));
  });
}

class _FakePaperRepository implements PaperRepository {
  @override
  List<Paper> getAll() => const [];
}

class _FakeAiService implements ChatAiService {
  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async {
    return '';
  }
}
