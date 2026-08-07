import 'dart:convert';

import '../domain/paper.dart';
import 'providers/arxiv/arxiv_paper_dto.dart';
import 'providers/arxiv/arxiv_paper_mapper.dart';

class ArxivJsonlImporter {
  const ArxivJsonlImporter({this.targetCategories = defaultArxivCategories});

  static const defaultArxivCategories = <String>{
    'cs.AI',
    'cs.CL',
    'cs.CV',
    'cs.IR',
    'cs.LG',
    'cs.RO',
    'cs.SE',
    'stat.ML',
  };

  final Set<String> targetCategories;

  Stream<Paper> parseLines(Stream<String> lines) async* {
    await for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('arXiv JSONL 行不是对象。');
      }
      final dto = _dtoFromJson(decoded);
      if (_isTarget(dto)) {
        yield const ArxivPaperMapper().toDomain(dto);
      }
    }
  }

  Paper fromJson(Map<String, dynamic> json) {
    return const ArxivPaperMapper().toDomain(_dtoFromJson(json));
  }

  ArxivPaperDto _dtoFromJson(Map<String, dynamic> json) {
    final versions = json['versions'];
    final version =
        versions is List && versions.isNotEmpty ? versions.length : 1;
    final firstVersion =
        versions is List && versions.isNotEmpty ? versions.first : null;
    final publishedAt = firstVersion is Map ? firstVersion['created'] : null;
    return ArxivPaperDto(
      id: _requiredString(json, 'id'),
      title: _cleanText(_requiredString(json, 'title')),
      authors: _parseAuthors(json['authors']),
      summary: _cleanText(_requiredString(json, 'abstract')),
      categories: _requiredString(json, 'categories').split(RegExp(r'\s+')),
      publishedAt: _parseDate(publishedAt ?? json['update_date']),
      updatedAt: _parseDate(json['update_date']),
      primaryCategory: _optionalString(json['primary_category']),
      doi: _optionalString(json['doi']),
      journalReference: _optionalString(json['journal-ref']),
      comment: _optionalString(json['comments']),
      license: _optionalString(json['license']),
      version: version,
    );
  }

  bool _isTarget(ArxivPaperDto dto) {
    return dto.categories.any(targetCategories.contains);
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('arXiv JSONL 缺少字段：$key');
    }
    return value;
  }

  static String? _optionalString(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  static List<String> _parseAuthors(dynamic value) {
    if (value is! String || value.trim().isEmpty) return const [];
    return value
        .split(RegExp(r'\s+and\s+|\s*,\s*'))
        .map((author) => author.trim())
        .where((author) => author.isNotEmpty)
        .toList(growable: false);
  }

  static DateTime _parseDate(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      final dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(trimmed);
      if (dateOnly != null) {
        return DateTime.utc(
          int.parse(dateOnly.group(1)!),
          int.parse(dateOnly.group(2)!),
          int.parse(dateOnly.group(3)!),
        );
      }
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) return parsed.toUtc();
      final rfc = RegExp(
        r'^(?:\w{3},\s*)?(\d{1,2})\s+(\w{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (rfc != null) {
        const monthNumbers = {
          'jan': 1,
          'feb': 2,
          'mar': 3,
          'apr': 4,
          'may': 5,
          'jun': 6,
          'jul': 7,
          'aug': 8,
          'sep': 9,
          'oct': 10,
          'nov': 11,
          'dec': 12,
        };
        final month = monthNumbers[rfc.group(2)!.toLowerCase()];
        if (month != null) {
          return DateTime.utc(
            int.parse(rfc.group(3)!),
            month,
            int.parse(rfc.group(1)!),
            int.parse(rfc.group(4)!),
            int.parse(rfc.group(5)!),
            int.parse(rfc.group(6)!),
          );
        }
      }
    }
    throw const FormatException('arXiv JSONL 日期格式无效。');
  }

  static String _cleanText(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();
}
