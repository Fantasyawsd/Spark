import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'arxiv_atom_dto.dart';
import 'arxiv_catalog_source.dart';
import 'arxiv_id.dart';

typedef ArxivClock = DateTime Function();
typedef ArxivDelay = Future<void> Function(Duration duration);

enum ArxivApiErrorKind { http, timeout, invalidResponse }

class ArxivApiException implements Exception {
  const ArxivApiException(this.kind, this.message, [this.cause]);

  final ArxivApiErrorKind kind;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class ArxivAtomClient implements ArxivCatalogSource {
  ArxivAtomClient({
    this.endpoint = 'https://export.arxiv.org/api/query',
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 15),
    this.minimumRequestInterval = const Duration(seconds: 3),
    this.maxServerRetries = 1,
    ArxivClock? clock,
    ArxivDelay? delay,
  })  : assert(maxServerRetries >= 0),
        _client = client ?? http.Client(),
        _ownsClient = client == null,
        _clock = clock ?? DateTime.now,
        _delay = delay ?? Future<void>.delayed;

  final String endpoint;
  final Duration requestTimeout;
  final Duration minimumRequestInterval;
  final int maxServerRetries;
  final http.Client _client;
  final bool _ownsClient;
  final ArxivClock _clock;
  final ArxivDelay _delay;

  DateTime? _lastRequestAt;
  Future<void> _requestQueue = Future<void>.value();

  @override
  Future<ArxivAtomPageDto> loadLatest({
    String? category,
    required int offset,
    required int limit,
  }) {
    final normalizedCategory = category?.trim();
    return _query({
      'search_query': normalizedCategory == null || normalizedCategory.isEmpty
          ? 'all:*'
          : normalizedCategory
              .split('|')
              .map((category) => 'cat:${category.trim()}')
              .join(' OR '),
      'start': '$offset',
      'max_results': '$limit',
      'sortBy': 'submittedDate',
      'sortOrder': 'descending',
    });
  }

  @override
  Future<ArxivAtomPageDto> search({
    required String term,
    required int offset,
    required int limit,
  }) {
    final normalizedTerm = term.trim().replaceAll('"', ' ');
    return _query({
      'search_query': 'all:"$normalizedTerm"',
      'start': '$offset',
      'max_results': '$limit',
      'sortBy': 'relevance',
      'sortOrder': 'descending',
    });
  }

  @override
  Future<ArxivAtomPaperDto?> findById(String paperId) async {
    final page = await _query({
      'id_list': normalizeArxivId(paperId),
      'start': '0',
      'max_results': '1',
    });
    return page.entries.firstOrNull;
  }

  void close() {
    if (_ownsClient) _client.close();
  }

  Future<ArxivAtomPageDto> _query(Map<String, String> parameters) async {
    final uri = Uri.parse(endpoint).replace(queryParameters: parameters);
    final operation = _requestQueue.then((_) => _performRequest(uri));
    _requestQueue = operation.then<void>((_) {}, onError: (_, __) {});
    return operation;
  }

  Future<ArxivAtomPageDto> _performRequest(
    Uri uri, {
    int serverRetryCount = 0,
  }) async {
    await _respectRequestInterval();
    _lastRequestAt = _clock();

    final http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: const {'user-agent': 'PaperFlow/1.0'},
      ).timeout(requestTimeout);
    } on TimeoutException catch (error) {
      throw ArxivApiException(
        ArxivApiErrorKind.timeout,
        'arXiv 请求超时。',
        error,
      );
    } on Object catch (error) {
      throw ArxivApiException(
        ArxivApiErrorKind.http,
        '无法连接 arXiv。',
        error,
      );
    }

    if (_isServerError(response.statusCode) &&
        serverRetryCount < maxServerRetries) {
      return _performRequest(
        uri,
        serverRetryCount: serverRetryCount + 1,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ArxivApiException(
        ArxivApiErrorKind.http,
        'arXiv 请求失败（HTTP ${response.statusCode}）。',
      );
    }
    try {
      return _parse(response.body);
    } on Object catch (error) {
      if (error is ArxivApiException) rethrow;
      throw ArxivApiException(
        ArxivApiErrorKind.invalidResponse,
        'arXiv 返回了无法解析的数据。',
        error,
      );
    }
  }

  Future<void> _respectRequestInterval() async {
    final lastRequestAt = _lastRequestAt;
    if (lastRequestAt == null || minimumRequestInterval <= Duration.zero) {
      return;
    }
    final elapsed = _clock().difference(lastRequestAt);
    final remaining = minimumRequestInterval - elapsed;
    if (remaining > Duration.zero) await _delay(remaining);
  }

  static bool _isServerError(int statusCode) =>
      statusCode >= 500 && statusCode < 600;

  ArxivAtomPageDto _parse(String body) {
    final document = XmlDocument.parse(body);
    final feed = document.rootElement;
    final entries =
        _childElements(feed, 'entry').map(_parseEntry).toList(growable: false);
    final startIndex = _intElement(feed, 'startIndex') ?? 0;
    final itemsPerPage = _intElement(feed, 'itemsPerPage') ?? entries.length;
    final totalResults = _intElement(feed, 'totalResults') ?? entries.length;
    final consumed = startIndex + entries.length;
    return ArxivAtomPageDto(
      entries: entries,
      startIndex: startIndex,
      itemsPerPage: itemsPerPage,
      totalResults: totalResults,
      nextOffset: entries.isNotEmpty && consumed < totalResults
          ? startIndex + (itemsPerPage > 0 ? itemsPerPage : entries.length)
          : null,
    );
  }

  ArxivAtomPaperDto _parseEntry(XmlElement entry) {
    final rawId = _requiredText(entry, 'id');
    final id = normalizeArxivId(rawId);
    final links = _childElements(entry, 'link').toList(growable: false);
    final paperUrl =
        _linkHref(links, rel: 'alternate') ?? 'https://arxiv.org/abs/$id';
    final pdfUrl = _linkHref(links, title: 'pdf') ??
        _linkHref(links, type: 'application/pdf') ??
        'https://arxiv.org/pdf/$id';
    final authorElements =
        _childElements(entry, 'author').toList(growable: false);
    return ArxivAtomPaperDto(
      id: id,
      title: _normalizeWhitespace(_requiredText(entry, 'title')),
      summary: _normalizeWhitespace(_requiredText(entry, 'summary')),
      authors: authorElements
          .map((author) => _optionalText(author, 'name'))
          .whereType<String>()
          .toList(growable: false),
      affiliations: authorElements
          .map((author) => _optionalText(author, 'affiliation'))
          .whereType<String>()
          .toSet()
          .toList(growable: false),
      categories: _childElements(entry, 'category')
          .map((category) => category.getAttribute('term')?.trim())
          .whereType<String>()
          .where((category) => category.isNotEmpty)
          .toList(growable: false),
      primaryCategory: _childElements(entry, 'primary_category')
          .firstOrNull
          ?.getAttribute('term')
          ?.trim(),
      publishedAt: _requiredDate(entry, 'published'),
      updatedAt: _requiredDate(entry, 'updated'),
      paperUrl: paperUrl,
      pdfUrl: pdfUrl,
      doi: _optionalText(entry, 'doi'),
      journalReference: _optionalText(entry, 'journal_ref'),
      comment: _optionalText(entry, 'comment'),
      license: _optionalText(entry, 'license'),
    );
  }

  static String? _linkHref(
    Iterable<XmlElement> links, {
    String? rel,
    String? title,
    String? type,
  }) {
    for (final link in links) {
      if (rel != null && link.getAttribute('rel') != rel) continue;
      if (title != null && link.getAttribute('title') != title) continue;
      if (type != null && link.getAttribute('type') != type) continue;
      final href = link.getAttribute('href')?.trim();
      if (href != null && href.isNotEmpty) return href;
    }
    return null;
  }

  static String _requiredText(XmlElement parent, String name) {
    final value = _optionalText(parent, name);
    if (value == null) throw FormatException('arXiv Atom 缺少字段：$name');
    return value;
  }

  static String? _optionalText(XmlElement parent, String name) {
    final value = _childElements(parent, name).firstOrNull?.innerText.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static DateTime _requiredDate(XmlElement parent, String name) {
    final value = _requiredText(parent, name);
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw FormatException('arXiv Atom 日期无效：$name');
    return parsed.toUtc();
  }

  static int? _intElement(XmlElement parent, String name) {
    final value = _childElements(parent, name).firstOrNull?.innerText.trim();
    return value == null ? null : int.tryParse(value);
  }

  static String _normalizeWhitespace(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static Iterable<XmlElement> _childElements(
    XmlElement parent,
    String localName,
  ) {
    return parent.childElements.where(
      (element) => element.name.local == localName,
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
