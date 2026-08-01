import '../domain/paper_reading_repository.dart';

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
      readPaperIds: _stringList(json, 'readPaperIds'),
      readLaterPaperIds: _stringList(json, 'readLaterPaperIds'),
      historyPaperIds: _stringList(json, 'historyPaperIds'),
      tabIndices: _intMap(json, 'tabIndices'),
      abstractScrollOffsets: _doubleMap(json, 'abstractScrollOffsets'),
      dwellMilliseconds: _intMap(json, 'dwellMilliseconds'),
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

  static List<String> _stringList(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value == null) return const [];
    if (value is! List || value.any((item) => item is! String)) {
      throw FormatException('$key must be a string list.');
    }
    return value.cast<String>().toList(growable: false);
  }

  static Map<String, int> _intMap(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value == null) return const {};
    if (value is! Map ||
        value.entries.any(
          (entry) => entry.key is! String || entry.value is! int,
        )) {
      throw FormatException('$key must map strings to integers.');
    }
    return Map<String, int>.from(value);
  }

  static Map<String, double> _doubleMap(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value == null) return const {};
    if (value is! Map ||
        value.entries.any(
          (entry) => entry.key is! String || entry.value is! num,
        )) {
      throw FormatException('$key must map strings to numbers.');
    }
    return {
      for (final entry in value.entries)
        entry.key as String: (entry.value as num).toDouble(),
    };
  }
}
