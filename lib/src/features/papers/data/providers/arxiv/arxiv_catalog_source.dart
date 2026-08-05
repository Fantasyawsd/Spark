import 'arxiv_atom_dto.dart';

abstract interface class ArxivCatalogSource {
  Future<ArxivAtomPageDto> loadLatest({
    String? category,
    DateTime? publishedFrom,
    DateTime? publishedUntil,
    required int offset,
    required int limit,
  });

  Future<ArxivAtomPageDto> search({
    required String term,
    required int offset,
    required int limit,
  });

  Future<ArxivAtomPaperDto?> findById(String paperId);
}
