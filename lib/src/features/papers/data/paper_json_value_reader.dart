/// Type-safe readers for primitive values shared by paper JSON mappers.
class PaperJsonValueReader {
  const PaperJsonValueReader._();

  static List<String> stringList(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return const [];
    if (value is! List || value.any((item) => item is! String)) {
      throw FormatException('$key must be a string list.');
    }
    return value.cast<String>().toList(growable: false);
  }

  static Map<String, int> intMap(Map<String, dynamic> json, String key) {
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

  static Map<String, String> stringMap(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return const {};
    if (value is! Map ||
        value.entries.any(
          (entry) => entry.key is! String || entry.value is! String,
        )) {
      throw FormatException('$key must map strings to strings.');
    }
    return Map<String, String>.from(value);
  }

  static Map<String, double> doubleMap(Map<String, dynamic> json, String key) {
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

  static int optionalInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return 0;
    if (value is! int) throw FormatException('$key must be an integer.');
    return value;
  }
}
