import '../../../core/storage/local_json_store.dart';
import '../../../core/storage/versioned_local_json_store.dart';
import '../domain/paper_translation.dart';
import 'cache/paper_record_cache_policy.dart';
import 'paper_translation_cache_record.dart';
import 'paper_translation_json_mapper.dart';

const paperTranslationDefaultCachePolicy = PaperRecordCachePolicy(
  ttl: Duration(days: 90),
  maxEntries: 256,
);

class FilePaperTranslationRepository implements PaperTranslationRepository {
  FilePaperTranslationRepository({
    LocalJsonStore? store,
    DateTime Function()? clock,
    PaperRecordCachePolicy policy = paperTranslationDefaultCachePolicy,
  })  : _clock = clock ?? DateTime.now,
        _policy = _validatedPolicy(policy),
        _store = VersionedLocalJsonStore(
          store ?? LocalJsonStore(fileName: 'paper_translations.json'),
          schemaId: 'papers.translations',
          schemaVersion: 2,
          migrations: const {1: _discardLegacyTranslations},
          validatePayload: PaperTranslationJsonMapper.validatePayload,
        );

  static Object? _discardLegacyTranslations(Object? _) {
    return <String, dynamic>{};
  }

  final VersionedLocalJsonStore _store;
  final DateTime Function() _clock;
  final PaperRecordCachePolicy _policy;

  static PaperRecordCachePolicy _validatedPolicy(
    PaperRecordCachePolicy policy,
  ) {
    policy.validate();
    return policy;
  }

  @override
  Future<PaperTranslationRecord?> load(String paperId) async {
    try {
      final json = await _store.readMap();
      if (json == null) return null;
      final value = json[paperId];
      if (value == null) return null;
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Paper translation record is invalid.');
      }
      final record = PaperTranslationJsonMapper.fromJson(paperId, value);
      return _policy.isExpired(record.generatedAt, _clock())
          ? null
          : record.toDomain();
    } catch (error) {
      throw PaperTranslationPersistenceException('无法读取中文翻译。', error);
    }
  }

  @override
  Future<void> save(PaperTranslationRecord record) async {
    try {
      final cacheRecord = PaperTranslationCacheRecord.fromDomain(record);
      await _store.updateMap((current) {
        final json = current ?? <String, dynamic>{};
        json[cacheRecord.paperId] = PaperTranslationJsonMapper.toJson(
          cacheRecord,
        );
        return retainNewestPaperRecords(
          json,
          now: _clock(),
          policy: _policy,
          timestampOf: (paperId, value) =>
              PaperTranslationJsonMapper.fromJson(paperId, value).generatedAt,
        );
      });
    } catch (error) {
      throw PaperTranslationPersistenceException('无法保存中文翻译。', error);
    }
  }

  @override
  Future<void> clear(String paperId) async {
    try {
      await _store.updateMap((json) {
        if (json == null) return null;
        json.remove(paperId);
        return json;
      });
    } catch (error) {
      throw PaperTranslationPersistenceException('无法清除中文翻译。', error);
    }
  }
}
