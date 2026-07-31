import '../application/paper_translation_service.dart';

class InMemoryPaperTranslationRepository implements PaperTranslationRepository {
  final Map<String, String> _translations = {};

  @override
  Future<String?> load(String paperId) async => _translations[paperId];

  @override
  Future<void> save(String paperId, String markdown) async {
    _translations[paperId] = markdown;
  }

  @override
  Future<void> clear(String paperId) async {
    _translations.remove(paperId);
  }
}
