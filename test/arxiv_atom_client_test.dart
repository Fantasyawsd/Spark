import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:spark/src/features/papers/data/providers/arxiv/arxiv_atom_client.dart';
import 'package:spark/src/features/papers/data/providers/arxiv/arxiv_atom_mapper.dart';

void main() {
  group('ArxivAtomClient', () {
    test('parses Atom metadata and uses official offset pagination', () async {
      final client = _RecordingClient([_response(_atomFeed)]);
      final api = ArxivAtomClient(
        endpoint: 'https://example.test/api/query',
        client: client,
        minimumRequestInterval: Duration.zero,
      );

      final page = await api.loadLatest(
        category: 'cs.AI',
        offset: 20,
        limit: 10,
      );

      final request = client.requests.single.url;
      expect(request.queryParameters['search_query'], 'cat:cs.AI');
      expect(request.queryParameters['start'], '20');
      expect(request.queryParameters['max_results'], '10');
      expect(request.queryParameters['sortBy'], 'submittedDate');
      expect(page.nextOffset, 30);

      final entry = page.entries.single;
      expect(entry.id, '2401.00001');
      expect(entry.publishedAt, DateTime.utc(2024, 1, 2));
      expect(entry.updatedAt, DateTime.utc(2024, 2, 3, 4, 5, 6));
      expect(entry.authors, ['Alice Smith', 'Bob Jones']);
      expect(entry.affiliations, ['Spark Lab']);
      expect(entry.categories, ['cs.AI', 'cs.LG']);
      expect(entry.primaryCategory, 'cs.AI');
      expect(entry.doi, '10.1000/test');
      expect(entry.journalReference, 'ICLR 2024');
      expect(entry.paperUrl, 'https://arxiv.org/abs/2401.00001v2');
      expect(entry.pdfUrl, 'https://arxiv.org/pdf/2401.00001v2');

      final paper = const ArxivAtomMapper().toDomain(entry);
      expect(paper.id, '2401.00001');
      expect(paper.arxivId, '2401.00001');
      expect(paper.firstAffiliation, 'Spark Lab');
      expect(paper.publishedAt, isNot(paper.updatedAt));
    });

    test('builds keyword and id queries with stable versionless ids', () async {
      final client = _RecordingClient([
        _response(_emptyFeed),
        _response(_atomFeed),
      ]);
      final api = ArxivAtomClient(
        endpoint: 'https://example.test/api/query',
        client: client,
        minimumRequestInterval: Duration.zero,
      );

      await api.search(term: 'large language model', offset: 40, limit: 20);
      final result = await api.findById('arXiv:2401.00001v7');

      expect(
          client.requests[0].url.queryParameters, containsPair('start', '40'));
      expect(
        client.requests[0].url.queryParameters,
        containsPair('search_query', 'all:"large language model"'),
      );
      expect(
        client.requests[1].url.queryParameters['id_list'],
        '2401.00001',
      );
      expect(result?.id, '2401.00001');
    });

    test('builds a compound category query for broad product topics', () async {
      final client = _RecordingClient([_response(_emptyFeed)]);
      final api = ArxivAtomClient(
        endpoint: 'https://example.test/api/query',
        client: client,
        minimumRequestInterval: Duration.zero,
      );

      await api.loadLatest(
        category: 'cs.CL|cs.AI',
        offset: 0,
        limit: 20,
      );

      expect(
        client.requests.single.url.queryParameters['search_query'],
        'cat:cs.CL OR cat:cs.AI',
      );
    });

    test('default feed uses the CS category union instead of all:*', () async {
      final client = _RecordingClient([_response(_emptyFeed)]);
      final api = ArxivAtomClient(
        endpoint: 'https://example.test/api/query',
        client: client,
        minimumRequestInterval: Duration.zero,
      );

      await api.loadLatest(category: null, offset: 0, limit: 20);

      final query = client.requests.single.url.queryParameters['search_query']!;
      expect(query, startsWith('cat:cs.AI OR cat:cs.AR'));
      expect(query, isNot(contains('all:*')));
    });

    test('adds UTC submitted-date bounds to category queries', () async {
      final client = _RecordingClient([_response(_emptyFeed)]);
      final api = ArxivAtomClient(
        endpoint: 'https://example.test/api/query',
        client: client,
        minimumRequestInterval: Duration.zero,
      );

      await api.loadLatest(
        category: 'cs.AI',
        publishedFrom: DateTime.utc(2026, 8, 1),
        publishedUntil: DateTime.utc(2026, 8, 6, 23, 59, 59),
        offset: 0,
        limit: 20,
      );

      expect(
        client.requests.single.url.queryParameters['search_query'],
        '(cat:cs.AI) AND submittedDate:[20260801000000 TO 20260806235959]',
      );
    });

    test('serializes requests and injects the three-second throttle', () async {
      var now = DateTime.utc(2024, 1, 1);
      final delays = <Duration>[];
      final client = _RecordingClient([
        _response(_emptyFeed),
        _response(_emptyFeed),
      ]);
      final api = ArxivAtomClient(
        endpoint: 'https://example.test/api/query',
        client: client,
        clock: () => now,
        delay: (duration) async {
          delays.add(duration);
          now = now.add(duration);
        },
      );

      await Future.wait([
        api.loadLatest(offset: 0, limit: 10),
        api.loadLatest(offset: 10, limit: 10),
      ]);

      expect(delays, [const Duration(seconds: 3)]);
      expect(client.requests, hasLength(2));
    });

    test('maps non-success HTTP responses to an API failure', () async {
      final api = ArxivAtomClient(
        client: _RecordingClient([http.Response('busy', 429)]),
        minimumRequestInterval: Duration.zero,
      );

      await expectLater(
        api.loadLatest(offset: 0, limit: 10),
        throwsA(
          isA<ArxivApiException>().having(
            (error) => error.kind,
            'kind',
            ArxivApiErrorKind.http,
          ),
        ),
      );
    });

    test('retries one transient server failure before reporting an error',
        () async {
      final client = _RecordingClient([
        http.Response('temporary failure', 500),
        _response(_emptyFeed),
      ]);
      final api = ArxivAtomClient(
        client: client,
        minimumRequestInterval: Duration.zero,
      );

      final page = await api.loadLatest(
        category: 'cs.AI',
        offset: 0,
        limit: 10,
      );

      expect(page.entries, isEmpty);
      expect(client.requests, hasLength(2));
    });

    test('stops after the configured server retry limit', () async {
      final client = _RecordingClient([
        http.Response('temporary failure', 500),
        http.Response('still failing', 500),
      ]);
      final api = ArxivAtomClient(
        client: client,
        minimumRequestInterval: Duration.zero,
      );

      await expectLater(
        api.loadLatest(category: 'cs.AI', offset: 0, limit: 10),
        throwsA(
          isA<ArxivApiException>().having(
            (error) => error.message,
            'message',
            contains('HTTP 500'),
          ),
        ),
      );
      expect(client.requests, hasLength(2));
    });

    test('maps request timeout without waiting for the default timeout',
        () async {
      final api = ArxivAtomClient(
        client: _NeverCompletesClient(),
        requestTimeout: const Duration(milliseconds: 1),
        minimumRequestInterval: Duration.zero,
      );

      await expectLater(
        api.loadLatest(offset: 0, limit: 10),
        throwsA(
          isA<ArxivApiException>().having(
            (error) => error.kind,
            'kind',
            ArxivApiErrorKind.timeout,
          ),
        ),
      );
    });
  });
}

class _RecordingClient extends http.BaseClient {
  _RecordingClient(this.responses);

  final List<http.Response> responses;
  final List<http.BaseRequest> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final response = responses.removeAt(0);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}

class _NeverCompletesClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return Completer<http.StreamedResponse>().future;
  }
}

http.Response _response(String body) => http.Response(
      body,
      200,
      headers: const {'content-type': 'application/atom+xml; charset=utf-8'},
    );

const _emptyFeed = '''
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom"
      xmlns:opensearch="http://a9.com/-/spec/opensearch/1.1/">
  <opensearch:totalResults>0</opensearch:totalResults>
  <opensearch:startIndex>0</opensearch:startIndex>
  <opensearch:itemsPerPage>10</opensearch:itemsPerPage>
</feed>
''';

const _atomFeed = '''
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom"
      xmlns:opensearch="http://a9.com/-/spec/opensearch/1.1/"
      xmlns:arxiv="http://arxiv.org/schemas/atom">
  <opensearch:totalResults>35</opensearch:totalResults>
  <opensearch:startIndex>20</opensearch:startIndex>
  <opensearch:itemsPerPage>10</opensearch:itemsPerPage>
  <entry>
    <id>http://arxiv.org/abs/2401.00001v2</id>
    <updated>2024-02-03T04:05:06Z</updated>
    <published>2024-01-02T00:00:00Z</published>
    <title> A paper\n title </title>
    <summary> First line.\n Second line. </summary>
    <author><name>Alice Smith</name><arxiv:affiliation>Spark Lab</arxiv:affiliation></author>
    <author><name>Bob Jones</name></author>
    <category term="cs.AI" />
    <category term="cs.LG" />
    <arxiv:primary_category term="cs.AI" />
    <arxiv:doi>10.1000/test</arxiv:doi>
    <arxiv:journal_ref>ICLR 2024</arxiv:journal_ref>
    <arxiv:comment>12 pages</arxiv:comment>
    <arxiv:license>http://creativecommons.org/licenses/by/4.0/</arxiv:license>
    <link href="https://arxiv.org/abs/2401.00001v2" rel="alternate" type="text/html" />
    <link href="https://arxiv.org/pdf/2401.00001v2" rel="related" type="application/pdf" title="pdf" />
  </entry>
</feed>
''';
