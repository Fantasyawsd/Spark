/// Type-safe readers for primitive values shared by paper JSON mappers.
class PaperJsonValueReader {
  const PaperJsonValueReader._();

  static Map<String, dynamic> stringMapValue(Object? value, String label) {
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw FormatException('$label must be an object.');
    }
    return Map<String, dynamic>.from(value);
  }

  static List<dynamic> list(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! List) throw FormatException('$key must be a list.');
    return List<dynamic>.from(value);
  }

  static List<String> stringList(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return const [];
    if (value is! List || value.any((item) => item is! String)) {
      throw FormatException('$key must be a string list.');
    }
    return value.cast<String>().toList(growable: false);
  }

  static List<String> requiredStringList(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
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

  static int? nullableInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! int) throw FormatException('$key must be an integer.');
    return value;
  }

  static int requiredInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! int) throw FormatException('$key must be an integer.');
    return value;
  }

  static String requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String) throw FormatException('$key must be a string.');
    return value;
  }

  static String requiredNonEmptyString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key must be a non-empty string.');
    }
    return value;
  }

  static String optionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return '';
    if (value is! String) throw FormatException('$key must be a string.');
    return value;
  }

  static String? nullableString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String) throw FormatException('$key must be a string.');
    return value;
  }

  static bool optionalBool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return false;
    if (value is! bool) throw FormatException('$key must be a boolean.');
    return value;
  }
}
