import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/papers/data/paper_translation_cache_record.dart';
import 'package:spark/src/features/papers/data/paper_translation_json_mapper.dart';
import 'package:spark/src/features/papers/domain/paper_translation.dart';

void main() {
  test('translation cache record maps between JSON and the domain entity', () {
    final generatedAt = DateTime.utc(2026, 8, 13, 9, 30);
    final translation = PaperTranslationRecord(
      paperId: 'paper-1',
      markdown: '中文翻译',
      inputFingerprint: 'fingerprint-1',
      promptVersion: 2,
      generatedAt: generatedAt,
    );

    final cacheRecord = PaperTranslationCacheRecord.fromDomain(translation);
    final json = PaperTranslationJsonMapper.toJson(cacheRecord);
    final restoredRecord = PaperTranslationJsonMapper.fromJson(
      translation.paperId,
      json,
    );
    final restored = restoredRecord.toDomain();

    expect(restoredRecord, isA<PaperTranslationCacheRecord>());
    expect(restored.paperId, translation.paperId);
    expect(restored.markdown, translation.markdown);
    expect(restored.inputFingerprint, translation.inputFingerprint);
    expect(restored.promptVersion, translation.promptVersion);
    expect(restored.generatedAt, generatedAt);
    expect(json, {
      'markdown': translation.markdown,
      'inputFingerprint': translation.inputFingerprint,
      'promptVersion': translation.promptVersion,
      'generatedAt': generatedAt.toIso8601String(),
    });
  });
}
