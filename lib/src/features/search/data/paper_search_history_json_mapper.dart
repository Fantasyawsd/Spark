class PaperSearchHistoryJsonMapper {
  const PaperSearchHistoryJsonMapper._();

  static void validatePayload(Object? payload) {
    if (payload is! List || payload.any((item) => item is! String)) {
      throw const FormatException(
          'Search history payload must be a string list.');
    }
  }

  static List<String> fromJson(List<dynamic> json) {
    validatePayload(json);
    return json
        .cast<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
