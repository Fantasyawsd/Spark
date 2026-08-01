class PaperTranslationJsonMapper {
  const PaperTranslationJsonMapper._();

  static void validatePayload(Object? payload) {
    if (payload is! Map<String, dynamic> ||
        payload.entries.any((entry) => entry.value is! String)) {
      throw const FormatException(
        'Paper translation payload must map paper IDs to strings.',
      );
    }
  }

  static Map<String, String> fromJson(Map<String, dynamic> json) {
    validatePayload(json);
    return Map<String, String>.from(json);
  }
}
