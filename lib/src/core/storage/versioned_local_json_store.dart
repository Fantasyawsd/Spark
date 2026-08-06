import 'local_json_store.dart';

typedef LocalJsonMigration = Object? Function(Object? payload);
typedef LocalJsonFormatMigration = Map<String, dynamic> Function(
  Map<String, dynamic> envelope,
);
typedef LocalJsonPayloadValidator = void Function(Object? payload);
typedef LocalJsonMapUpdate = Map<String, dynamic>? Function(
  Map<String, dynamic>? current,
);

class VersionedLocalJsonStore {
  VersionedLocalJsonStore(
    this._store, {
    required this.schemaId,
    this.schemaVersion = currentSchemaVersion,
    this.migrations = const {},
    this.formatMigrations = const {},
    this.validatePayload,
  }) : assert(schemaVersion > 0);

  static const format = 'spark.local-json';
  static const currentFormatVersion = 1;
  static const currentSchemaVersion = 1;

  final LocalJsonStore _store;
  final String schemaId;
  final int schemaVersion;
  final Map<int, LocalJsonMigration> migrations;
  final Map<int, LocalJsonFormatMigration> formatMigrations;
  final LocalJsonPayloadValidator? validatePayload;
  bool _hasObservedState = false;
  bool _observedFileExists = false;
  int _observedRevision = 0;

  Future<Map<String, dynamic>?> readMap() {
    return _store.transaction((transaction) async {
      final payload = await _readPayload(transaction);
      if (payload == null) {
        _observeMissingFile();
        return null;
      }
      final result = await _validatedMap(transaction, payload.value);
      if (payload.requiresRewrite) {
        await _write(transaction, result, baseRevision: payload.revision);
      } else {
        _observeExistingFile(payload.revision);
      }
      return result;
    });
  }

  Future<List<dynamic>?> readList() {
    return _store.transaction((transaction) async {
      final payload = await _readPayload(transaction);
      if (payload == null) {
        _observeMissingFile();
        return null;
      }
      final result = await _validatedList(transaction, payload.value);
      if (payload.requiresRewrite) {
        await _write(transaction, result, baseRevision: payload.revision);
      } else {
        _observeExistingFile(payload.revision);
      }
      return result;
    });
  }

  Future<void> writeMap(Map<String, dynamic> payload) {
    return _store.transaction((transaction) async {
      final current = await _readPayload(transaction);
      if (current != null) {
        await _validatedMap(transaction, current.value);
      }
      _ensureSnapshotIsCurrent(current);
      _validateCandidate(payload);
      await _write(
        transaction,
        payload,
        baseRevision: current?.revision ?? 0,
      );
    });
  }

  Future<void> writeList(List<dynamic> payload) {
    return _store.transaction((transaction) async {
      final current = await _readPayload(transaction);
      if (current != null) {
        await _validatedList(transaction, current.value);
      }
      _ensureSnapshotIsCurrent(current);
      _validateCandidate(payload);
      await _write(
        transaction,
        payload,
        baseRevision: current?.revision ?? 0,
      );
    });
  }

  Future<void> updateMap(LocalJsonMapUpdate update) {
    return _store.transaction((transaction) async {
      final current = await _readAndValidateExistingMap(transaction);
      final updated = update(current == null ? null : Map.of(current));
      if (updated == null) return;
      _validateCandidate(updated);
      final stored = await _readPayload(transaction);
      await _write(
        transaction,
        updated,
        baseRevision: stored?.revision ?? 0,
      );
    });
  }

  Future<Map<String, dynamic>?> _readAndValidateExistingMap(
    LocalJsonStoreTransaction transaction,
  ) async {
    final current = await _readPayload(transaction);
    if (current == null) return null;
    return _validatedMap(transaction, current.value);
  }

  Future<_VersionedPayload?> _readPayload(
    LocalJsonStoreTransaction transaction,
  ) async {
    final Object? decoded;
    try {
      decoded = await transaction.read();
    } on LocalJsonDecodingException catch (error) {
      await _quarantineAndThrow(transaction, error);
    }
    if (decoded == null) return null;
    if (decoded is! Map<String, dynamic>) {
      return _VersionedPayload(decoded, requiresRewrite: true, revision: 0);
    }
    if (!decoded.containsKey('_format')) {
      return _VersionedPayload(decoded, requiresRewrite: true, revision: 0);
    }

    final storedFormat = decoded['_format'];
    if (storedFormat != format) {
      throw UnsupportedLocalStorageFormatException(storedFormat);
    }
    var formatVersion = decoded['formatVersion'] ?? currentFormatVersion;
    if (formatVersion is! int ||
        formatVersion < 0 ||
        (formatVersion == 0 && !formatMigrations.containsKey(0))) {
      await _quarantineAndThrow(
        transaction,
        const FormatException('Local storage format version must be positive.'),
      );
    }
    if (formatVersion > currentFormatVersion) {
      throw UnsupportedLocalStorageFormatVersionException(
        storedVersion: formatVersion,
        supportedVersion: currentFormatVersion,
      );
    }
    var normalizedEnvelope = Map<String, dynamic>.from(decoded);
    var formatRequiresRewrite = !decoded.containsKey('formatVersion');
    while (formatVersion < currentFormatVersion) {
      final migration = formatMigrations[formatVersion];
      if (migration == null) {
        throw MissingLocalFormatMigrationException(formatVersion);
      }
      try {
        normalizedEnvelope = migration(normalizedEnvelope);
      } on FormatException catch (error) {
        await _quarantineAndThrow(transaction, error);
      }
      final migratedFormatVersion = normalizedEnvelope['formatVersion'];
      if (migratedFormatVersion != formatVersion + 1) {
        await _quarantineAndThrow(
          transaction,
          FormatException(
            'Local format migration must produce version ${formatVersion + 1}.',
          ),
        );
      }
      formatVersion = migratedFormatVersion as int;
      formatRequiresRewrite = true;
    }

    final storedSchema = normalizedEnvelope['schema'];
    if (storedSchema != null && storedSchema is! String) {
      await _quarantineAndThrow(
        transaction,
        const FormatException('Local data schema identifier must be a string.'),
      );
    }
    if (storedSchema is String && storedSchema != schemaId) {
      throw LocalSchemaMismatchException(
        storedSchema: storedSchema,
        expectedSchema: schemaId,
      );
    }
    final storedVersion = normalizedEnvelope['schemaVersion'];
    if (storedVersion is! int || storedVersion <= 0) {
      await _quarantineAndThrow(
        transaction,
        const FormatException('Local data schema version must be positive.'),
      );
    }
    if (storedVersion > schemaVersion) {
      throw UnsupportedLocalSchemaVersionException(
        storedVersion: storedVersion,
        supportedVersion: schemaVersion,
      );
    }
    if (!normalizedEnvelope.containsKey('payload')) {
      await _quarantineAndThrow(
        transaction,
        const FormatException('Local data envelope has no payload.'),
      );
    }
    final storedRevision = normalizedEnvelope['revision'] ?? 0;
    if (storedRevision is! int || storedRevision < 0) {
      await _quarantineAndThrow(
        transaction,
        const FormatException('Local data revision must be non-negative.'),
      );
    }

    var migratedPayload = normalizedEnvelope['payload'];
    var migratedVersion = storedVersion;
    while (migratedVersion < schemaVersion) {
      final migration = migrations[migratedVersion];
      if (migration == null) {
        throw MissingLocalSchemaMigrationException(
          schemaId: schemaId,
          fromVersion: migratedVersion,
          toVersion: migratedVersion + 1,
        );
      }
      try {
        migratedPayload = migration(migratedPayload);
      } on FormatException catch (error) {
        await _quarantineAndThrow(transaction, error);
      }
      migratedVersion++;
    }
    return _VersionedPayload(
      migratedPayload,
      requiresRewrite: formatRequiresRewrite ||
          !normalizedEnvelope.containsKey('revision') ||
          storedSchema == null ||
          storedVersion != schemaVersion,
      revision: storedRevision,
    );
  }

  Future<Map<String, dynamic>> _validatedMap(
    LocalJsonStoreTransaction transaction,
    Object? value,
  ) async {
    if (value is! Map<String, dynamic>) {
      await _quarantineAndThrow(
        transaction,
        const FormatException('Local data payload must be an object.'),
      );
    }
    final result = Map<String, dynamic>.from(value as Map);
    await _validateStored(transaction, result);
    return result;
  }

  Future<List<dynamic>> _validatedList(
    LocalJsonStoreTransaction transaction,
    Object? value,
  ) async {
    if (value is! List) {
      await _quarantineAndThrow(
        transaction,
        const FormatException('Local data payload must be a list.'),
      );
    }
    final result = List<dynamic>.from(value);
    await _validateStored(transaction, result);
    return result;
  }

  Future<void> _validateStored(
    LocalJsonStoreTransaction transaction,
    Object? payload,
  ) async {
    try {
      validatePayload?.call(payload);
    } on FormatException catch (error) {
      await _quarantineAndThrow(transaction, error);
    }
  }

  void _validateCandidate(Object? payload) {
    validatePayload?.call(payload);
  }

  Future<void> _write(
    LocalJsonStoreTransaction transaction,
    Object payload, {
    required int baseRevision,
  }) async {
    final revision = baseRevision + 1;
    await transaction.write({
      '_format': format,
      'formatVersion': currentFormatVersion,
      'schema': schemaId,
      'schemaVersion': schemaVersion,
      'revision': revision,
      'payload': payload,
    });
    _observeExistingFile(revision);
  }

  void _ensureSnapshotIsCurrent(_VersionedPayload? current) {
    final currentExists = current != null;
    if (!_hasObservedState) {
      return;
    }
    if (_observedFileExists != currentExists ||
        (currentExists && _observedRevision != current.revision)) {
      throw const LocalConcurrentModificationException();
    }
  }

  void _observeMissingFile() {
    _hasObservedState = true;
    _observedFileExists = false;
    _observedRevision = 0;
  }

  void _observeExistingFile(int revision) {
    _hasObservedState = true;
    _observedFileExists = true;
    _observedRevision = revision;
  }

  Future<Never> _quarantineAndThrow(
    LocalJsonStoreTransaction transaction,
    Object cause,
  ) async {
    final backupPath = await transaction.quarantineCorruptFile();
    throw LocalDataCorruptionException(
      '本地数据已损坏，原文件已隔离。',
      cause: cause,
      backupPath: backupPath,
    );
  }
}

class LocalDataCorruptionException implements Exception {
  const LocalDataCorruptionException(
    this.message, {
    required this.cause,
    this.backupPath,
  });

  final String message;
  final Object cause;
  final String? backupPath;

  @override
  String toString() => message;
}

class UnsupportedLocalStorageFormatException implements Exception {
  const UnsupportedLocalStorageFormatException(this.storedFormat);

  final Object? storedFormat;

  @override
  String toString() => '无法读取未知的本地数据格式：$storedFormat。';
}

class UnsupportedLocalStorageFormatVersionException implements Exception {
  const UnsupportedLocalStorageFormatVersionException({
    required this.storedVersion,
    required this.supportedVersion,
  });

  final int storedVersion;
  final int supportedVersion;
}

class MissingLocalFormatMigrationException implements Exception {
  const MissingLocalFormatMigrationException(this.storedVersion);

  final int storedVersion;
}

class LocalSchemaMismatchException implements Exception {
  const LocalSchemaMismatchException({
    required this.storedSchema,
    required this.expectedSchema,
  });

  final String storedSchema;
  final String expectedSchema;
}

class UnsupportedLocalSchemaVersionException implements Exception {
  const UnsupportedLocalSchemaVersionException({
    required this.storedVersion,
    required this.supportedVersion,
  });

  final int storedVersion;
  final int supportedVersion;

  @override
  String toString() {
    return '本地数据版本 $storedVersion 高于当前支持版本 $supportedVersion。';
  }
}

class MissingLocalSchemaMigrationException implements Exception {
  const MissingLocalSchemaMigrationException({
    required this.schemaId,
    required this.fromVersion,
    required this.toVersion,
  });

  final String schemaId;
  final int fromVersion;
  final int toVersion;
}

class LocalConcurrentModificationException implements Exception {
  const LocalConcurrentModificationException();

  @override
  String toString() => '本地数据已被其他操作更新，请重新加载后再保存。';
}

class _VersionedPayload {
  const _VersionedPayload(
    this.value, {
    required this.requiresRewrite,
    required this.revision,
  });

  final Object? value;
  final bool requiresRewrite;
  final int revision;
}
