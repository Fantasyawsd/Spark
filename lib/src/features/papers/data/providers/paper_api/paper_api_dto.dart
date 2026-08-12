final class PaperApiPaperDto {
  const PaperApiPaperDto({
    required this.paperId,
    required this.title,
    required this.abstractText,
    required this.authors,
    required this.publishedAt,
    required this.updatedAt,
    required this.subjects,
    required this.externalIds,
    required this.discoverySources,
    required this.signals,
    required this.metadata,
  });

  factory PaperApiPaperDto.fromJson(Map<String, dynamic> json) {
    if (json['schema_version'] != 'paper.v1') {
      throw const FormatException('Paper API paper schema is not paper.v1.');
    }
    return PaperApiPaperDto(
      paperId: _requiredString(json, 'paper_id'),
      title: _requiredString(json, 'title'),
      abstractText: _optionalString(json['abstract']),
      authors: _stringList(json['authors'], field: 'authors'),
      publishedAt: _requiredDateTime(json, 'published_at'),
      updatedAt: _optionalDateTime(json['updated_at'], field: 'updated_at'),
      subjects: _stringList(json['subjects'], field: 'subjects'),
      externalIds: _stringMap(json['external_ids'], field: 'external_ids'),
      discoverySources: _stringList(
        json['discovery_sources'],
        field: 'discovery_sources',
      ),
      signals: _nestedMap(json['signals'], field: 'signals'),
      metadata: _dynamicMap(json['metadata'], field: 'metadata'),
    );
  }

  final String paperId;
  final String title;
  final String? abstractText;
  final List<String> authors;
  final DateTime publishedAt;
  final DateTime? updatedAt;
  final List<String> subjects;
  final Map<String, String> externalIds;
  final List<String> discoverySources;
  final Map<String, Map<String, dynamic>> signals;
  final Map<String, dynamic> metadata;
}

final class PaperApiPageDto {
  const PaperApiPageDto({
    required this.channel,
    required this.items,
    required this.nextCursor,
  });

  factory PaperApiPageDto.fromJson(
    Map<String, dynamic> json, {
    required String expectedChannel,
  }) {
    if (json['schema_version'] != 'api.v1') {
      throw const FormatException('Paper API response schema is not api.v1.');
    }
    final channel = _requiredString(json, 'channel');
    if (channel != expectedChannel) {
      throw FormatException(
        'Paper API returned channel $channel instead of $expectedChannel.',
      );
    }
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const FormatException('Paper API items must be a list.');
    }
    return PaperApiPageDto(
      channel: channel,
      items: rawItems.map((item) {
        if (item is! Map) {
          throw const FormatException('Paper API item must be an object.');
        }
        return PaperApiPaperDto.fromJson(Map<String, dynamic>.from(item));
      }).toList(growable: false),
      nextCursor: _optionalString(json['next_cursor']),
    );
  }

  final String channel;
  final List<PaperApiPaperDto> items;
  final String? nextCursor;
}

String _requiredString(Map<String, dynamic> json, String field) {
  final value = _optionalString(json[field]);
  if (value == null) throw FormatException('Paper API is missing $field.');
  return value;
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  if (value is! String) {
    throw const FormatException('Paper API string field has invalid type.');
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime _requiredDateTime(Map<String, dynamic> json, String field) {
  final value = _optionalDateTime(json[field], field: field);
  if (value == null) throw FormatException('Paper API is missing $field.');
  return value;
}

DateTime? _optionalDateTime(Object? value, {required String field}) {
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('Paper API $field must be an ISO-8601 string.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Paper API $field is not a valid date.');
  }
  return parsed.toUtc();
}

List<String> _stringList(Object? value, {required String field}) {
  if (value is! List) {
    throw FormatException('Paper API $field must be a list.');
  }
  return value.map((item) {
    if (item is! String || item.trim().isEmpty) {
      throw FormatException('Paper API $field contains an invalid value.');
    }
    return item.trim();
  }).toList(growable: false);
}

Map<String, String> _stringMap(Object? value, {required String field}) {
  if (value is! Map) {
    throw FormatException('Paper API $field must be an object.');
  }
  final result = <String, String>{};
  for (final entry in value.entries) {
    if (entry.key is! String || entry.value is! String) {
      throw FormatException('Paper API $field contains an invalid value.');
    }
    final key = (entry.key as String).trim();
    final item = (entry.value as String).trim();
    if (key.isNotEmpty && item.isNotEmpty) result[key] = item;
  }
  return result;
}

Map<String, dynamic> _dynamicMap(Object? value, {required String field}) {
  if (value is! Map) {
    throw FormatException('Paper API $field must be an object.');
  }
  return Map<String, dynamic>.from(value);
}

Map<String, Map<String, dynamic>> _nestedMap(
  Object? value, {
  required String field,
}) {
  final source = _dynamicMap(value, field: field);
  final result = <String, Map<String, dynamic>>{};
  for (final entry in source.entries) {
    if (entry.value is! Map) {
      throw FormatException('Paper API $field contains an invalid value.');
    }
    result[entry.key] = Map<String, dynamic>.from(entry.value as Map);
  }
  return result;
}
