import 'package:flutter/material.dart';
import 'package:paperflow/paperflow.dart';

void main() {
  runApp(
    PaperFlowApp(
      commentRepository: FilePaperCommentRepository(),
      interactionRepository: FilePaperInteractionRepository(),
      preferenceRepository: FilePaperPreferenceRepository(),
      searchHistoryRepository: FilePaperSearchHistoryRepository(),
      shareService: const PlatformPaperShareService(),
      aiService: DeepSeekPaperAiService(),
      webSearchAiService: DeepSeekWebSearchAiService(),
      aiSessionRepository: FilePaperAiSessionRepository(),
      translationServiceFactory: const DeepSeekPaperTranslationServiceFactory(),
      translationRepository: FilePaperTranslationRepository(),
    ),
  );
}
