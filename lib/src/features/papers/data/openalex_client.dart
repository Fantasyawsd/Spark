import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/paper_source.dart';
import '../domain/paper_sync_ports.dart';

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
    final normalized = arxivId.replaceFirst(RegExp(r'^arXiv:'), '').trim();
    final uri = Uri.parse(endpoint).replace(
      queryParameters: {'filter': 'ids.arxiv:$normalized', 'per-page': '1'},
    );
    final response =
        await _client.get(uri, headers: {'Accept': 'application/json'});
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OpenAlexSourceException(
          'OpenAlex 请求失败（HTTP ${response.statusCode}）。');
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('OpenAlex 返回格式无效。');
    }
    final results = payload['results'];
    if (results is! List || results.isEmpty || results.first is! Map) {
      return null;
    }
    final work = results.first as Map;
    final institutions = _institutionNames(work['authorships']);
    final concepts = _conceptNames(work['concepts']);
    return PaperEnhancement(
      citationCount: work['cited_by_count'] is num
          ? (work['cited_by_count'] as num).toInt()
          : null,
      institutions: institutions,
      concepts: concepts,
      relatedWorkIds: _relatedIds(work['related_works']),
    );
  }

  void close() {
    if (_ownsClient) _client.close();
  }

  static List<String> _institutionNames(dynamic authorships) {
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

  static List<String> _conceptNames(dynamic concepts) {
    if (concepts is! List) return const [];
    return concepts
        .whereType<Map>()
        .map((concept) => concept['display_name'])
        .whereType<String>()
        .take(8)
        .toList(growable: false);
  }

  static List<String> _relatedIds(dynamic relatedWorks) {
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
