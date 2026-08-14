import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spark/src/features/papers/data/providers/paper_api/paper_api_client.dart';
import 'package:spark/src/features/papers/domain/paper_catalog.dart';

void main() {
  test('推荐请求携带匿名画像并保持无原始行为', () async {
    Uri? captured;
    final mock = MockClient((request) async {
      captured = request.url;
      return http.Response(
        jsonEncode({
          'schema_version': 'api.v1',
          'channel': 'recommended',
          'items': <Object>[],
          'next_cursor': null,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = PaperApiClient(baseUrl: 'http://localhost:8080', client: mock);
    await client.loadFeed(
      const PaperFeedQuery(
        channel: PaperFeedChannel.recommended,
        profileSubjects: {'cs.AI': 2.5},
        profileKeywords: {'多模态': 1.5},
        profileVenues: {'NeurIPS': 0.25},
      ),
    );
    final encoded = captured!.queryParameters['profile'];
    expect(encoded, isNotNull);
    final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(encoded!))))
        as Map<String, dynamic>;
    expect(payload['profile_version'], 'profile.v1');
    expect((payload['subjects'] as Map)['cs.AI'], 2.5);
    expect((payload['keywords'] as Map)['多模态'], 1.5);
    expect((payload['venues'] as Map)['NeurIPS'], 0.25);
    expect(payload.containsKey('events'), isFalse);
  });

  test('无画像时不携带 profile 参数', () async {
    Uri? captured;
    final mock = MockClient((request) async {
      captured = request.url;
      return http.Response(
        jsonEncode({
          'schema_version': 'api.v1',
          'channel': 'recommended',
          'items': <Object>[],
          'next_cursor': null,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = PaperApiClient(baseUrl: 'http://localhost:8080', client: mock);
    await client.loadFeed(const PaperFeedQuery(channel: PaperFeedChannel.recommended));
    expect(captured!.queryParameters.containsKey('profile'), isFalse);
  });
}
