import '../domain/paper_preference_repository.dart';
import 'paper_json_value_reader.dart';

class PaperPreferenceJsonMapper {
  const PaperPreferenceJsonMapper._();

  static void validatePayload(Object? payload) {
    if (payload is! Map<String, dynamic>) {
      throw const FormatException(
        'Paper preference payload must be an object.',
      );
    }
    fromJson(payload);
  }

  static PaperPreferences fromJson(Map<String, dynamic> json) {
    return PaperPreferences(
      extraTopics: PaperJsonValueReader.stringList(json, 'extraTopics'),
      positions: PaperJsonValueReader.intMap(json, 'positions'),
      timeRanges: PaperJsonValueReader.stringMap(json, 'timeRanges'),
      primaryCategoryIndex: PaperJsonValueReader.optionalInt(
        json,
        'primaryCategoryIndex',
      ),
      topicIndex: PaperJsonValueReader.optionalInt(json, 'topicIndex'),
    );
  }

  static Map<String, dynamic> toJson(PaperPreferences preferences) {
    return {
      'extraTopics': preferences.extraTopics,
      'positions': preferences.positions,
      'timeRanges': preferences.timeRanges,
      'primaryCategoryIndex': preferences.primaryCategoryIndex,
      'topicIndex': preferences.topicIndex,
    };
  }
}
