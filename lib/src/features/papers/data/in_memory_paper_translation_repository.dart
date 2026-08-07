import '../domain/paper_translation.dart';

class InMemoryPaperTranslationRepository implements PaperTranslationRepository {
  final Map<String, PaperTranslationRecord> _translations = {};

  @override
  Future<PaperTranslationRecord?> load(String paperId) async =>
      _translations[paperId];

  @override
  Future<void> save(PaperTranslationRecord record) async {
    _translations[record.paperId] = record;
  }

  @override
  Future<void> clear(String paperId) async {
    _translations.remove(paperId);
  }
}
