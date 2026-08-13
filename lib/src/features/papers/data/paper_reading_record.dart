import '../domain/paper_reading_repository.dart';

/// Persistence-shaped representation of reading state.
class PaperReadingRecord {
  PaperReadingRecord({
    Iterable<String> readPaperIds = const [],
    Iterable<String> readLaterPaperIds = const [],
    Iterable<String> historyPaperIds = const [],
    Map<String, int> tabIndices = const {},
    Map<String, double> abstractScrollOffsets = const {},
    Map<String, int> dwellMilliseconds = const {},
  })  : readPaperIds = List.unmodifiable(readPaperIds),
        readLaterPaperIds = List.unmodifiable(readLaterPaperIds),
        historyPaperIds = List.unmodifiable(historyPaperIds),
        tabIndices = Map.unmodifiable(tabIndices),
        abstractScrollOffsets = Map.unmodifiable(abstractScrollOffsets),
        dwellMilliseconds = Map.unmodifiable(dwellMilliseconds);

  factory PaperReadingRecord.fromDomain(PaperReadingSnapshot snapshot) {
    return PaperReadingRecord(
      readPaperIds: snapshot.readPaperIds,
      readLaterPaperIds: snapshot.readLaterPaperIds,
      historyPaperIds: snapshot.historyPaperIds,
      tabIndices: snapshot.tabIndices,
      abstractScrollOffsets: snapshot.abstractScrollOffsets,
      dwellMilliseconds: snapshot.dwellMilliseconds,
    );
  }

  final List<String> readPaperIds;
  final List<String> readLaterPaperIds;
  final List<String> historyPaperIds;
  final Map<String, int> tabIndices;
  final Map<String, double> abstractScrollOffsets;
  final Map<String, int> dwellMilliseconds;

  PaperReadingSnapshot toDomain() {
    return PaperReadingSnapshot(
      readPaperIds: readPaperIds,
      readLaterPaperIds: readLaterPaperIds,
      historyPaperIds: historyPaperIds,
      tabIndices: tabIndices,
      abstractScrollOffsets: abstractScrollOffsets,
      dwellMilliseconds: dwellMilliseconds,
    );
  }
}
