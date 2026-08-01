import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../domain/paper_source.dart';
import '../domain/paper_sync_ports.dart';

class ArxivOaiClient implements ArxivMetadataSource {
  ArxivOaiClient({
    this.endpoint = 'https://oaipmh.arxiv.org/oai',
    http.Client? client,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final String endpoint;
  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<ArxivMetadataPage> listRecords({
    String? set,
    DateTime? from,
    DateTime? until,
    String? resumptionToken,
  }) async {
    final parameters = <String, String>{
      'verb': 'ListRecords',
      if (resumptionToken != null) 'resumptionToken': resumptionToken,
      if (resumptionToken == null) ...{
        'metadataPrefix': 'arXiv',
        if (set != null) 'set': set,
        if (from != null) 'from': _formatDate(from),
        if (until != null) 'until': _formatDate(until),
      },
    };
    final response = await _client
        .get(Uri.parse(endpoint).replace(queryParameters: parameters));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ArxivSourceException(
          'arXiv OAI 请求失败（HTTP ${response.statusCode}）。');
    }
    return _parse(response.body);
  }

  Future<List<ArxivMetadata>> listAll({
    String? set,
    DateTime? from,
    DateTime? until,
    void Function(String token)? onToken,
  }) async {
    final records = <ArxivMetadata>[];
    String? token;
    do {
      final page = await listRecords(
          set: set, from: from, until: until, resumptionToken: token);
      records.addAll(page.records);
      token = page.resumptionToken;
      if (token != null) onToken?.call(token);
    } while (token != null);
    return records;
  }

  void close() {
    if (_ownsClient) _client.close();
  }

  ArxivMetadataPage _parse(String body) {
    final document = XmlDocument.parse(body);
    final error = document.findAllElements('error').firstOrNull;
    if (error != null) {
      throw ArxivSourceException(error.innerText.trim());
    }
    final records = document
        .findAllElements('record')
        .map(_parseRecord)
        .toList(growable: false);
    final token = document
        .findAllElements('resumptionToken')
        .firstOrNull
        ?.innerText
        .trim();
    return ArxivMetadataPage(
      records: records,
      resumptionToken: token == null || token.isEmpty ? null : token,
    );
  }

  ArxivMetadata _parseRecord(XmlElement record) {
    final metadata = record.findAllElements('metadata').firstOrNull;
    final arxiv = metadata?.findAllElements('arXiv').firstOrNull;
    if (arxiv == null) throw const FormatException('arXiv OAI 记录缺少 arXiv 元数据。');
    final id = _text(arxiv, 'id');
    final authors = arxiv
        .findAllElements('author')
        .map((author) {
          final keyName =
              author.findAllElements('keyname').firstOrNull?.innerText.trim();
          final forenames =
              author.findAllElements('forenames').firstOrNull?.innerText.trim();
          return [forenames, keyName]
              .whereType<String>()
              .where((value) => value.isNotEmpty)
              .join(' ');
        })
        .where((author) => author.isNotEmpty)
        .toList(growable: false);
    final categories = _text(arxiv, 'categories').split(RegExp(r'\s+'));
    return ArxivMetadata(
      id: id,
      title: _text(arxiv, 'title'),
      authors: authors,
      abstractText: _text(arxiv, 'abstract'),
      categories: categories,
      primaryCategory: _textOrNull(arxiv, 'primary_category'),
      doi: _textOrNull(arxiv, 'doi'),
      journalReference: _textOrNull(arxiv, 'journal-ref'),
      comment: _textOrNull(arxiv, 'comments'),
      license:
          arxiv.findAllElements('license').firstOrNull?.getAttribute('uri'),
      publishedAt: _date(record, 'datestamp'),
      updatedAt: _date(record, 'datestamp'),
    );
  }

  static String _text(XmlElement parent, String name) {
    final value = parent.findAllElements(name).firstOrNull?.innerText.trim();
    if (value == null || value.isEmpty) {
      throw FormatException('arXiv OAI 缺少字段：$name');
    }
    return value.replaceAll(RegExp(r'\s+'), ' ');
  }

  static String? _textOrNull(XmlElement parent, String name) {
    final value = parent.findAllElements(name).firstOrNull?.innerText.trim();
    return value == null || value.isEmpty
        ? null
        : value.replaceAll(RegExp(r'\s+'), ' ');
  }

  static DateTime _date(XmlElement parent, String name) {
    final value = parent.findAllElements(name).firstOrNull?.innerText.trim();
    final date = value == null ? null : DateTime.tryParse(value);
    if (date == null) throw FormatException('arXiv OAI 日期格式无效：$name');
    return date.toUtc();
  }

  static String _formatDate(DateTime date) =>
      date.toUtc().toIso8601String().split('T').first;
}

class ArxivSourceException implements Exception {
  const ArxivSourceException(this.message);

  final String message;

  @override
  String toString() => message;
}

extension XmlElementFirstOrNull on Iterable<XmlElement> {
  XmlElement? get firstOrNull => isEmpty ? null : first;
}
