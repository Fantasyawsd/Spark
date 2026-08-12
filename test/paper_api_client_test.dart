import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spark/src/features/papers/data/providers/paper_api/paper_api_client.dart';
import 'package:spark/src/features/papers/domain/paper_catalog.dart';
import 'package:spark/src/features/papers/domain/paper_time_range.dart';

void main() {
  test(
    'recommended feed uses api.v1 and preserves its opaque cursor',
    () async {
      late Uri requestedUri;
      final client = PaperApiClient(
        baseUrl: 'http://127.0.0.1:8000/api/v1/',
        client: MockClient((request) async {
          requestedUri = request.url;
          return http.Response(
            jsonEncode({
              'schema_version': 'api.v1',
              'channel': 'recommended',
              'items': [_paperJson()],
              'next_cursor': 'opaque-page-2',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final page = await client.loadFeed(
        const PaperFeedQuery(
          channel: PaperFeedChannel.recommended,
          readPaperIds: ['paper-read'],
          limit: 7,
        ),
      );

      expect(requestedUri.path, '/api/v1/feed/recommended');
      expect(requestedUri.queryParameters['limit'], '7');
      expect(requestedUri.queryParameters['read_ids'], 'paper-read');
      expect(page.items.single.paperId, 'paper_fixture');
      expect(page.nextCursor, 'opaque-page-2');
    },
  );

  test('force refresh requests a new recommendation batch seed', () async {
    final requestedUris = <Uri>[];
    var nextSeed = 100;
    final client = PaperApiClient(
      baseUrl: 'http://127.0.0.1:8000/api/v1',
      seedGenerator: () => nextSeed++,
      client: MockClient((request) async {
        requestedUris.add(request.url);
        return http.Response(
          jsonEncode({
            'schema_version': 'api.v1',
            'channel': 'recommended',
            'batch_id': 'batch-${requestedUris.length}',
            'items': <Object>[],
            'next_cursor': null,
          }),
          200,
        );
      }),
    );

    await client.loadFeed(
      const PaperFeedQuery(
        channel: PaperFeedChannel.recommended,
        forceRefresh: true,
      ),
    );
    await client.loadFeed(
      const PaperFeedQuery(
        channel: PaperFeedChannel.recommended,
        forceRefresh: true,
      ),
    );

    expect(requestedUris[0].queryParameters['seed'], '100');
    expect(requestedUris[1].queryParameters['seed'], '101');
  });

  test('subject and following feeds encode channel-specific filters', () async {
    final requestedUris = <Uri>[];
    final client = PaperApiClient(
      baseUrl: 'http://localhost:8000/api/v1',
      client: MockClient((request) async {
        requestedUris.add(request.url);
        final channel =
            request.url.path.endsWith('/following') ? 'following' : 'subject';
        return http.Response(
          jsonEncode({
            'schema_version': 'api.v1',
            'channel': channel,
            'items': <Object>[],
            'next_cursor': null,
          }),
          200,
        );
      }),
    );

    await client.loadFeed(
      PaperFeedQuery(
        channel: PaperFeedChannel.subject,
        category: 'cs.AI',
        timeRange: PaperTimeRange.date(DateTime(2026, 8, 11)),
        cursor: 'cursor-value',
      ),
    );
    await client.loadFeed(
      const PaperFeedQuery(
        channel: PaperFeedChannel.following,
        followingAuthors: ['ada lovelace'],
      ),
    );

    expect(requestedUris.first.path, '/api/v1/channels/subject/cs.AI');
    expect(requestedUris.first.queryParameters['cursor'], 'cursor-value');
    expect(
      requestedUris.first.queryParameters,
      containsPair('from', isNotEmpty),
    );
    expect(requestedUris.first.queryParameters, containsPair('to', isNotEmpty));
    expect(requestedUris.last.path, '/api/v1/channels/following');
    expect(requestedUris.last.queryParameters['authors'], 'ada lovelace');
  });

  test('detail returns null for a Paper API 404', () async {
    final client = PaperApiClient(
      baseUrl: 'http://127.0.0.1:8000/api/v1',
      client: MockClient((_) async => http.Response('{}', 404)),
    );

    expect(await client.findById('paper_missing'), isNull);
  });

  test('invalid schema is exposed as an invalid-response error', () async {
    final client = PaperApiClient(
      baseUrl: 'http://127.0.0.1:8000/api/v1',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'schema_version': 'api.v2',
            'channel': 'latest',
            'items': <Object>[],
            'next_cursor': null,
          }),
          200,
        ),
      ),
    );

    await expectLater(
      client.loadFeed(const PaperFeedQuery()),
      throwsA(
        isA<PaperApiException>().having(
          (error) => error.kind,
          'kind',
          PaperApiErrorKind.invalidResponse,
        ),
      ),
    );
  });
}

Map<String, Object?> _paperJson() => {
      'paper_id': 'paper_fixture',
      'title': 'Fixture AI Paper',
      'abstract': 'A deterministic fixture.',
      'authors': ['Ada Lovelace'],
      'published_at': '2026-08-11T00:00:00Z',
      'updated_at': null,
      'subjects': ['cs.AI'],
      'external_ids': {'arxiv_id': '2401.99999'},
      'discovery_sources': ['arxiv'],
      'signals': {
        'openalex': {'citation_count': 4},
      },
      'metadata': <String, Object?>{},
      'admitted': true,
      'admission_reason': 'arxiv_subject:cs.AI',
      'withdrawn': false,
      'schema_version': 'paper.v1',
      'provenance': <Object>[],
    };
