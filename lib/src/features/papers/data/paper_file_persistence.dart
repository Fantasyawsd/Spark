import '../../../core/storage/local_json_store.dart';
import '../../../core/storage/versioned_local_json_store.dart';

typedef PaperPersistenceErrorFactory<T extends Object> = T Function(
    Object cause);

class PaperFilePersistence {
  PaperFilePersistence({
    required String fileName,
    required String schemaId,
    LocalJsonStore? store,
    int schemaVersion = VersionedLocalJsonStore.currentSchemaVersion,
    Map<int, LocalJsonMigration> migrations = const {},
    LocalJsonPayloadValidator? validatePayload,
  }) : store = VersionedLocalJsonStore(
          store ?? LocalJsonStore(fileName: fileName),
          schemaId: schemaId,
          schemaVersion: schemaVersion,
          migrations: migrations,
          validatePayload: validatePayload,
        );

  final VersionedLocalJsonStore store;

  Future<T> guard<T, E extends Object>(
    Future<T> Function() operation,
    PaperPersistenceErrorFactory<E> onError,
  ) async {
    try {
      return await operation();
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(onError(error), stackTrace);
    }
  }
}
