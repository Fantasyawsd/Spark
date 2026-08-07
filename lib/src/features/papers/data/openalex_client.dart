import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/paper_enhancement.dart';
import '../domain/paper_sync_ports.dart';
import 'providers/arxiv/arxiv_id.dart';

class OpenAlexClient implements PaperEnhancementSource {
  OpenAlexClient({
    this.endpoint = 'https://api.openalex.org/works',
    http.Client? client,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final String endpoint;
  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<PaperEnhancement?> findByArxivId(String arxivId) async {
    final normalized = normalizeArxivId(arxivId);
    final uri = Uri.parse(endpoint).replace(
      queryParameters: {'filter': 'ids.arxiv:$normalized', 'per-page': '1'},
    );
    final response =
        await _client.get(uri, headers: {'Accept': 'application/json'});
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OpenAlexSourceException(
          'OpenAlex 请求失败（HTTP ${response.statusCode}）。');
    }
    final payload = _OpenAlexResponseDto.fromJson(jsonDecode(response.body));
    return payload.works.isEmpty ? null : payload.works.first.toDomain();
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

class _OpenAlexResponseDto {
  const _OpenAlexResponseDto(this.works);

  factory _OpenAlexResponseDto.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('OpenAlex 返回格式无效。');
    }
    final results = json['results'];
    if (results is! List || results.isEmpty || results.first is! Map) {
      return const _OpenAlexResponseDto([]);
    }
    return _OpenAlexResponseDto(
      [
        _OpenAlexWorkDto.fromJson(
          Map<String, dynamic>.from(results.first as Map),
        ),
      ],
    );
  }

  final List<_OpenAlexWorkDto> works;
}

class _OpenAlexWorkDto {
  const _OpenAlexWorkDto({
    required this.citationCount,
    required this.institutions,
    required this.concepts,
    required this.relatedWorkIds,
  });

  factory _OpenAlexWorkDto.fromJson(Map<String, dynamic> json) {
    final citationCount = json['cited_by_count'];
    return _OpenAlexWorkDto(
      citationCount: citationCount is num ? citationCount.toInt() : null,
      institutions: _institutionNames(json['authorships']),
      concepts: _conceptNames(json['concepts']),
      relatedWorkIds: _relatedIds(json['related_works']),
    );
  }

  final int? citationCount;
  final List<String> institutions;
  final List<String> concepts;
  final List<String> relatedWorkIds;

  PaperEnhancement toDomain() {
    return PaperEnhancement(
      citationCount: citationCount,
      institutions: institutions,
      concepts: concepts,
      relatedWorkIds: relatedWorkIds,
    );
  }

  static List<String> _institutionNames(Object? authorships) {
    if (authorships is! List) return const [];
    return authorships
        .whereType<Map>()
        .expand((authorship) => authorship['institutions'] is List
            ? authorship['institutions'] as List
            : const [])
        .whereType<Map>()
        .map((institution) => institution['display_name'])
        .whereType<String>()
        .toSet()
        .toList(growable: false);
  }

  static List<String> _conceptNames(Object? concepts) {
    if (concepts is! List) return const [];
    return concepts
        .whereType<Map>()
        .map((concept) => concept['display_name'])
        .whereType<String>()
        .take(8)
        .toList(growable: false);
  }

  static List<String> _relatedIds(Object? relatedWorks) {
    if (relatedWorks is! List) return const [];
    return relatedWorks.whereType<String>().take(12).toList(growable: false);
  }
}

class OpenAlexSourceException implements Exception {
  const OpenAlexSourceException(this.message);

  final String message;

  @override
  String toString() => message;
}
