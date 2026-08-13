import 'paper_reading_record.dart';
import 'paper_json_value_reader.dart';

class PaperReadingJsonMapper {
  const PaperReadingJsonMapper._();

  static void validatePayload(Object? payload) {
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Paper reading payload must be an object.');
    }
    fromJson(payload);
  }

  static PaperReadingRecord fromJson(Map<String, dynamic> json) {
    return PaperReadingRecord(
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

  static Map<String, dynamic> toJson(PaperReadingRecord snapshot) {
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
