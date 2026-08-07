import 'arxiv_paper_dto.dart';

abstract interface class ArxivCatalogSource {
  Future<ArxivPaperPageDto> loadLatest({
    String? category,
    DateTime? publishedFrom,
    DateTime? publishedUntil,
    required int offset,
    required int limit,
  });

  Future<ArxivPaperPageDto> search({
    required String term,
    required int offset,
    required int limit,
  });

  Future<ArxivPaperDto?> findById(String paperId);
}
