import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../domain/paper_catalog.dart';
import 'paper_api_dto.dart';

enum PaperApiErrorKind { network, timeout, http, invalidResponse }

final class PaperApiException implements Exception {
  const PaperApiException(this.kind, this.message, [this.cause]);

  final PaperApiErrorKind kind;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

abstract interface class PaperApiSource {
  Future<PaperApiPageDto> loadFeed(PaperFeedQuery query);

  Future<PaperApiPaperDto?> findById(String paperId);
}

final class PaperApiClient implements PaperApiSource {
  PaperApiClient({
    required String baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
    int Function()? seedGenerator,
  })  : _baseUri = Uri.parse(baseUrl),
        _client = client ?? http.Client(),
        _seedGenerator = seedGenerator ?? _defaultSeedGenerator;

  final Uri _baseUri;
  final http.Client _client;
  final Duration timeout;
  final int Function() _seedGenerator;

  @override
  Future<PaperApiPageDto> loadFeed(PaperFeedQuery query) async {
    try {
      final request = _feedRequest(query);
      final json = await _getJson(request.uri);
      return PaperApiPageDto.fromJson(
        json,
        expectedChannel: request.expectedChannel,
      );
    } on PaperApiException {
      rethrow;
    } on FormatException catch (error) {
      throw PaperApiException(
        PaperApiErrorKind.invalidResponse,
        'Paper API 返回了不符合契约的数据。',
        error,
      );
    }
  }

  @override
  Future<PaperApiPaperDto?> findById(String paperId) async {
    try {
      final uri = _uri(['papers', paperId]);
      final response = await _get(uri, allowedStatusCodes: const {404});
      if (response.statusCode == 404) return null;
      final json = _decode(response);
      return PaperApiPaperDto.fromJson(json);
    } on PaperApiException {
      rethrow;
    } on FormatException catch (error) {
      throw PaperApiException(
        PaperApiErrorKind.invalidResponse,
        'Paper API 返回了不符合契约的数据。',
        error,
      );
    }
  }

  ({Uri uri, String expectedChannel}) _feedRequest(PaperFeedQuery query) {
    final parameters = <String, String>{'limit': '${query.limit}'};
    final cursor = query.cursor?.trim();
    if (cursor?.isNotEmpty == true) parameters['cursor'] = cursor!;

    switch (query.channel) {
      case PaperFeedChannel.recommended:
        if (query.readPaperIds.isNotEmpty) {
          parameters['read_ids'] = query.readPaperIds.join(',');
        }
        if (query.forceRefresh) {
          parameters['seed'] = '${_seedGenerator()}';
        }
        return (
          uri: _uri(['feed', 'recommended'], parameters),
          expectedChannel: 'recommended',
        );
      case PaperFeedChannel.following:
        if (query.followingAuthors.isEmpty) {
          throw const PaperApiException(
            PaperApiErrorKind.invalidResponse,
            '关注频道缺少作者条件。',
          );
        }
        parameters['authors'] = query.followingAuthors.join(',');
        return (
          uri: _uri(['channels', 'following'], parameters),
          expectedChannel: 'following',
        );
      case PaperFeedChannel.latest:
        return (
          uri: _uri(['channels', 'latest'], parameters),
          expectedChannel: 'latest',
        );
      case PaperFeedChannel.subject:
        final subject = _requiredCategory(query);
        _addDateBounds(parameters, query);
        return (
          uri: _uri(['channels', 'subject', subject], parameters),
          expectedChannel: 'subject',
        );
      case PaperFeedChannel.conference:
        final venue = _requiredCategory(query);
        return (
          uri: _uri(['channels', 'conference', venue], parameters),
          expectedChannel: 'conference',
        );
    }
  }

  static int _defaultSeedGenerator() => DateTime.now().microsecondsSinceEpoch;

  void _addDateBounds(Map<String, String> parameters, PaperFeedQuery query) {
    final bounds = query.timeRange.bounds(now: DateTime.now());
    if (bounds == null) return;
    parameters['from'] = bounds.start.toUtc().toIso8601String();
    parameters['to'] = bounds.end.toUtc().toIso8601String();
  }

  String _requiredCategory(PaperFeedQuery query) {
    final category = query.category?.trim();
    if (category == null || category.isEmpty) {
      throw const PaperApiException(
        PaperApiErrorKind.invalidResponse,
        '频道查询缺少标识。',
      );
    }
    return category;
  }

  Uri _uri(List<String> segments, [Map<String, String>? parameters]) {
    return _baseUri.replace(
      pathSegments: [
        ..._baseUri.pathSegments.where((segment) => segment.isNotEmpty),
        ...segments,
      ],
      queryParameters: parameters?.isEmpty == true ? null : parameters,
    );
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await _get(uri);
    return _decode(response);
  }

  Future<http.Response> _get(
    Uri uri, {
    Set<int> allowedStatusCodes = const {},
  }) async {
    try {
      final response = await _client.get(uri).timeout(timeout);
      if ((response.statusCode < 200 || response.statusCode >= 300) &&
          !allowedStatusCodes.contains(response.statusCode)) {
        throw PaperApiException(
          PaperApiErrorKind.http,
          'Paper API 请求失败（HTTP ${response.statusCode}）。',
        );
      }
      return response;
    } on TimeoutException catch (error) {
      throw PaperApiException(
        PaperApiErrorKind.timeout,
        'Paper API 响应超时。',
        error,
      );
    } on http.ClientException catch (error) {
      throw PaperApiException(
        PaperApiErrorKind.network,
        '无法连接 Paper API。',
        error,
      );
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final value = jsonDecode(utf8.decode(response.bodyBytes));
      if (value is! Map) {
        throw const FormatException('Paper API response must be an object.');
      }
      return Map<String, dynamic>.from(value);
    } on FormatException catch (error) {
      throw PaperApiException(
        PaperApiErrorKind.invalidResponse,
        'Paper API 返回了无法解析的数据。',
        error,
      );
    }
  }
}
