import 'package:http/http.dart' as http;
import 'package:paperflow/paperflow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArxivJsonlImporter', () {
    test('filters target categories and maps snapshot fields', () async {
      const lines = '''
{"id":"2401.00001","title":" A  title\\n","authors":"Alice Smith, Bob Jones","abstract":"An abstract.","categories":"cs.AI cs.LG","primary_category":"cs.AI","update_date":"2024-01-03","versions":[{"version":"v1","created":"Mon, 01 Jan 2024 00:00:00 GMT"}]}
{"id":"2401.00002","title":"Other","authors":"Carol","abstract":"Other abstract","categories":"math.PR","update_date":"2024-01-03"}
''';

      final papers = await const ArxivJsonlImporter()
          .parseLines(Stream<String>.fromIterable(lines.trim().split('\n')))
          .toList();

      expect(papers, hasLength(1));
      expect(papers.single.normalizedId, '2401.00001');
      expect(papers.single.title, 'A title');
      expect(papers.single.publishedAt, DateTime.utc(2024, 1, 1));
      expect(papers.single.toPaper().source, 'arxiv');
    });
  });

  test('ArxivOaiClient follows a resumption token', () async {
    final client = _QueueClient([
      _response('''
<OAI-PMH><ListRecords>
<record><header><datestamp>2024-01-03</datestamp></header><metadata><arXiv><id>2401.00001</id><title>First</title><authors><author><keyname>Smith</keyname><forenames>Alice</forenames></author></authors><abstract>Abstract</abstract><categories>cs.AI</categories><primary_category>cs.AI</primary_category></arXiv></metadata></record>
<resumptionToken>next-token</resumptionToken>
</ListRecords></OAI-PMH>
'''),
      _response('''
<OAI-PMH><ListRecords>
<record><header><datestamp>2024-01-04</datestamp></header><metadata><arXiv><id>2401.00002</id><title>Second</title><authors><author><keyname>Jones</keyname><forenames>Bob</forenames></author></authors><abstract>Abstract 2</abstract><categories>cs.CL</categories></arXiv></metadata></record>
</ListRecords></OAI-PMH>
'''),
    ]);
    final api =
        ArxivOaiClient(endpoint: 'https://example.test/oai', client: client);

    final records = await api.listAll(set: 'cs:cs:AI');

    expect(records.map((record) => record.normalizedId),
        ['2401.00001', '2401.00002']);
    expect(client.requests, hasLength(2));
    expect(client.requests[0].queryParameters['metadataPrefix'], 'arXiv');
    expect(client.requests[1].queryParameters['resumptionToken'], 'next-token');
  });

  test('OpenAlex maps citation and enrichment fields', () async {
    final client = _QueueClient([
      _response('''
{"results":[{"cited_by_count":42,"authorships":[{"institutions":[{"display_name":"PaperFlow Lab"}]}],"concepts":[{"display_name":"Machine Learning"}],"related_works":["https://openalex.org/W1"]}]}
'''),
    ]);
    final api =
        OpenAlexClient(endpoint: 'https://example.test/works', client: client);

    final result = await api.findByArxivId('arXiv:2401.00001');

    expect(result?.citationCount, 42);
    expect(result?.institutions, ['PaperFlow Lab']);
    expect(client.requests.single.queryParameters['filter'],
        'ids.arxiv:2401.00001');
  });
}

class _QueueClient extends http.BaseClient {
  _QueueClient(this.responses);

  final List<http.Response> responses;
  final requests = <Uri>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request.url);
    final response = responses.removeAt(0);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}

http.Response _response(String body) =>
    http.Response(body, 200, headers: const {
      'content-type': 'application/xml',
    });
