import '../domain/paper_interaction_repository.dart';

class PaperInteractionJsonMapper {
  const PaperInteractionJsonMapper._();

  static void validatePayload(Object? payload) {
    if (payload is! Map<String, dynamic>) {
      throw const FormatException(
          'Paper interaction payload must be an object.');
    }
    _stringList(payload, 'likedPaperIds');
    _stringList(payload, 'savedPaperIds');
    _stringList(payload, 'followedPaperIds');
    _intMap(payload, 'shareCountDeltas');
  }

  static PaperInteractionSnapshot fromJson(Map<String, dynamic> json) {
    return PaperInteractionSnapshot(
      likedPaperIds: _stringList(json, 'likedPaperIds'),
      savedPaperIds: _stringList(json, 'savedPaperIds'),
      followedPaperIds: _stringList(json, 'followedPaperIds'),
      shareCountDeltas: _intMap(json, 'shareCountDeltas'),
    );
  }

  static Map<String, dynamic> toJson(PaperInteractionSnapshot snapshot) {
    return {
      'likedPaperIds': snapshot.likedPaperIds.toList(),
      'savedPaperIds': snapshot.savedPaperIds.toList(),
      'followedPaperIds': snapshot.followedPaperIds.toList(),
      'shareCountDeltas': snapshot.shareCountDeltas,
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
}
