import 'package:flutter/foundation.dart';

import '../../application/paper_keyword_controller.dart';
import '../../application/paper_translation_controller.dart';
import '../../application/paper_translation_service.dart';
import '../../domain/paper.dart';
import '../../domain/paper_keyword_repository.dart';
import '../../domain/paper_translation.dart';
import '../../../chat/chat.dart';

/// Owns the two derived-content controllers used by [PaperReaderCard].
///
/// Keeping replacement and disposal here makes widget lifecycle updates
/// independent from the presentation state machine.
class PaperReaderCardControllerSet {
  PaperReaderCardControllerSet({
    required Paper paper,
    required PaperTranslationServiceFactory translationServiceFactory,
    required ChatAiService keywordService,
    required PaperTranslationRepository? translationRepository,
    required PaperKeywordRepository? keywordRepository,
    required VoidCallback onTranslationChanged,
    required VoidCallback onKeywordChanged,
  })  : _onTranslationChanged = onTranslationChanged,
        _onKeywordChanged = onKeywordChanged,
        _paper = paper,
        _translationServiceFactory = translationServiceFactory,
        _translationRepository = translationRepository,
        _keywordService = keywordService,
        _keywordRepository = keywordRepository {
    _translationController = _createTranslationController();
    _keywordController = _createKeywordController();
  }

  final VoidCallback _onTranslationChanged;
  final VoidCallback _onKeywordChanged;
  Paper _paper;
  PaperTranslationServiceFactory _translationServiceFactory;
  PaperTranslationRepository? _translationRepository;
  ChatAiService _keywordService;
  PaperKeywordRepository? _keywordRepository;
  late PaperTranslationController _translationController;
  late PaperKeywordController _keywordController;

  PaperTranslationController get translation => _translationController;
  PaperKeywordController get keywords => _keywordController;

  PaperReaderCardControllerUpdate update({
    required Paper paper,
    required PaperTranslationServiceFactory translationServiceFactory,
    required ChatAiService keywordService,
    required PaperTranslationRepository? translationRepository,
    required PaperKeywordRepository? keywordRepository,
  }) {
    final paperChanged = _paper.id != paper.id;
    final translationChanged = paperChanged ||
        !identical(_translationServiceFactory, translationServiceFactory) ||
        !identical(_translationRepository, translationRepository);
    final keywordChanged = paperChanged ||
        !identical(_keywordService, keywordService) ||
        !identical(_keywordRepository, keywordRepository);

    if (translationChanged) {
      _replaceTranslationController(
        paper: paper,
        serviceFactory: translationServiceFactory,
        repository: translationRepository,
      );
    }
    if (keywordChanged) {
      _replaceKeywordController(
        paper: paper,
        service: keywordService,
        repository: keywordRepository,
      );
    }
    _paper = paper;
    _translationServiceFactory = translationServiceFactory;
    _translationRepository = translationRepository;
    _keywordService = keywordService;
    _keywordRepository = keywordRepository;
    return PaperReaderCardControllerUpdate(
      paperChanged: paperChanged,
      translationChanged: translationChanged,
      keywordChanged: keywordChanged,
    );
  }

  void cancel() {
    _translationController.cancel();
    _keywordController.cancel();
  }

  void dispose() {
    _translationController
      ..removeListener(_onTranslationChanged)
      ..dispose();
    _keywordController
      ..removeListener(_onKeywordChanged)
      ..dispose();
  }

  PaperTranslationController _createTranslationController() {
    return PaperTranslationController(
      paper: _paper,
      service: _translationServiceFactory.create(),
      repository: _translationRepository,
    )..addListener(_onTranslationChanged);
  }

  PaperKeywordController _createKeywordController() {
    return PaperKeywordController(
      paper: _paper,
      service: _keywordService,
      repository: _keywordRepository,
    )..addListener(_onKeywordChanged);
  }

  void _replaceTranslationController({
    required Paper paper,
    required PaperTranslationServiceFactory serviceFactory,
    required PaperTranslationRepository? repository,
  }) {
    _translationController
      ..removeListener(_onTranslationChanged)
      ..dispose();
    _paper = paper;
    _translationServiceFactory = serviceFactory;
    _translationRepository = repository;
    _translationController = _createTranslationController();
  }

  void _replaceKeywordController({
    required Paper paper,
    required ChatAiService service,
    required PaperKeywordRepository? repository,
  }) {
    _keywordController
      ..removeListener(_onKeywordChanged)
      ..dispose();
    _paper = paper;
    _keywordService = service;
    _keywordRepository = repository;
    _keywordController = _createKeywordController();
  }
}

@immutable
class PaperReaderCardControllerUpdate {
  const PaperReaderCardControllerUpdate({
    required this.paperChanged,
    required this.translationChanged,
    required this.keywordChanged,
  });

  final bool paperChanged;
  final bool translationChanged;
  final bool keywordChanged;
}
