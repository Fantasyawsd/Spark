import '../domain/paper_preference_repository.dart';

class PaperPreferenceJsonMapper {
  const PaperPreferenceJsonMapper._();

  static void validatePayload(Object? payload) {
    if (payload is! Map<String, dynamic>) {
      throw const FormatException(
          'Paper preference payload must be an object.');
    }
    fromJson(payload);
  }

  static PaperPreferences fromJson(Map<String, dynamic> json) {
    return PaperPreferences(
      extraTopics: _stringList(json, 'extraTopics'),
      positions: _intMap(json, 'positions'),
      primaryCategoryIndex: _optionalInt(json, 'primaryCategoryIndex'),
      topicIndex: _optionalInt(json, 'topicIndex'),
    );
  }

  static Map<String, dynamic> toJson(PaperPreferences preferences) {
    return {
      'extraTopics': preferences.extraTopics,
      'positions': preferences.positions,
      'primaryCategoryIndex': preferences.primaryCategoryIndex,
      'topicIndex': preferences.topicIndex,
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

  static int _optionalInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return 0;
    if (value is! int) throw FormatException('$key must be an integer.');
    return value;
  }
}
