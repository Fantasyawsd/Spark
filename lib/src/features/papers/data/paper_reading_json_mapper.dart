import '../domain/paper_reading_repository.dart';
import 'paper_json_value_reader.dart';

class PaperReadingJsonMapper {
  const PaperReadingJsonMapper._();

  static void validatePayload(Object? payload) {
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Paper reading payload must be an object.');
    }
    fromJson(payload);
  }

  static PaperReadingSnapshot fromJson(Map<String, dynamic> json) {
    return PaperReadingSnapshot(
      readPaperIds: PaperJsonValueReader.stringList(json, 'readPaperIds'),
      readLaterPaperIds: PaperJsonValueReader.stringList(
        json,
        'readLaterPaperIds',
      ),
      historyPaperIds: PaperJsonValueReader.stringList(json, 'historyPaperIds'),
      tabIndices: PaperJsonValueReader.intMap(json, 'tabIndices'),
      abstractScrollOffsets: PaperJsonValueReader.doubleMap(
        json,
        'abstractScrollOffsets',
      ),
      dwellMilliseconds: PaperJsonValueReader.intMap(json, 'dwellMilliseconds'),
    );
  }

  static Map<String, dynamic> toJson(PaperReadingSnapshot snapshot) {
    return {
      'readPaperIds': snapshot.readPaperIds.toList(),
      'readLaterPaperIds': snapshot.readLaterPaperIds.toList(),
      'historyPaperIds': snapshot.historyPaperIds,
      'tabIndices': snapshot.tabIndices,
      'abstractScrollOffsets': snapshot.abstractScrollOffsets,
      'dwellMilliseconds': snapshot.dwellMilliseconds,
    };
  }
}
