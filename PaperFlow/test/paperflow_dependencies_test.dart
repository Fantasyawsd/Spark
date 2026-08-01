import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/src/app/paperflow_dependencies.dart';
import 'package:paperflow/src/features/ai_settings/data/secure_deepseek_credential_repository.dart';
import 'package:paperflow/src/features/chat/domain/chat_context.dart';
import 'package:paperflow/src/features/papers/application/paper_ai_service.dart';
import 'package:paperflow/src/features/papers/domain/paper.dart';
import 'package:paperflow/src/features/papers/domain/paper_repository.dart';
import 'package:paperflow/src/features/papers/data/arxiv_seed_repository.dart';
import 'package:paperflow/src/features/papers/data/deepseek_paper_ai_service.dart';
import 'package:paperflow/src/features/papers/data/deepseek_web_search_ai_service.dart';
import 'package:paperflow/src/features/papers/data/file_paper_ai_session_repository.dart';
import 'package:paperflow/src/features/papers/data/file_paper_comment_repository.dart';
import 'package:paperflow/src/features/papers/data/file_paper_interaction_repository.dart';
import 'package:paperflow/src/features/papers/data/file_paper_preference_repository.dart';
import 'package:paperflow/src/features/papers/data/file_paper_reading_repository.dart';
import 'package:paperflow/src/features/papers/data/file_paper_translation_repository.dart';
import 'package:paperflow/src/features/papers/data/platform_paper_share_service.dart';
import 'package:paperflow/src/features/papers/data/offline_first_paper_catalog_repository.dart';

void main() {
  test('production dependencies compose concrete infrastructure once', () {
    final dependencies = PaperFlowDependencies.production();

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
    expect(dependencies.aiService, isA<DeepSeekPaperAiService>());
    expect(
      dependencies.webSearchAiService,
      isA<DeepSeekWebSearchAiService>(),
    );
    expect(
        dependencies.aiSessionRepository, isA<FilePaperAiSessionRepository>());
    expect(
      dependencies.translationRepository,
      isA<FilePaperTranslationRepository>(),
    );
    expect(dependencies.mainAiService, isA<DeepSeekPaperAiService>());
    expect(
      dependencies.mainWebSearchAiService,
      isA<DeepSeekWebSearchAiService>(),
    );
  });

  test('preview dependencies preserve overrides and default main chat wiring',
      () {
    final paperRepository = _FakePaperRepository();
    final aiService = _FakeAiService();
    final webSearchAiService = _FakeAiService();

    final dependencies = PaperFlowDependencies.preview(
      paperRepository: paperRepository,
      aiService: aiService,
      webSearchAiService: webSearchAiService,
    );

    expect(dependencies.paperRepository, same(paperRepository));
    expect(dependencies.aiService, same(aiService));
    expect(dependencies.webSearchAiService, same(webSearchAiService));
    expect(dependencies.mainAiService, same(aiService));
    expect(dependencies.mainWebSearchAiService, same(webSearchAiService));
  });

  test('preview dependencies allow separate main chat services', () {
    final paperAiService = _FakeAiService();
    final mainAiService = _FakeAiService();

    final dependencies = PaperFlowDependencies.preview(
      aiService: paperAiService,
      mainAiService: mainAiService,
    );

    expect(dependencies.aiService, same(paperAiService));
    expect(dependencies.mainAiService, same(mainAiService));
  });
}

class _FakePaperRepository implements PaperRepository {
  @override
  List<Paper> getAll() => const [];
}

class _FakeAiService implements PaperAiService {
  @override
  Future<String> answer({
    required ChatContext context,
    required List<PaperAiMessage> conversation,
  }) async {
    return '';
  }
}
