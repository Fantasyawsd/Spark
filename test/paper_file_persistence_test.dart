import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/core/storage/local_json_store.dart';
import 'package:spark/src/features/papers/data/paper_file_persistence.dart';

void main() {
  test('builds a versioned store with the requested schema', () async {
    final directory = await Directory.systemTemp.createTemp(
      'spark-paper-persistence-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}state.json');
    final persistence = PaperFilePersistence(
      fileName: 'unused.json',
      schemaId: 'papers.test',
      store: LocalJsonStore(fileName: 'unused.json', file: file),
    );

    await persistence.store.writeMap({'value': 1});

    expect(await persistence.store.readMap(), {'value': 1});
  });

  test('maps failures while preserving the original stack trace', () async {
    final persistence = PaperFilePersistence(
      fileName: 'unused.json',
      schemaId: 'papers.test',
    );
    Object? caught;
    StackTrace? stackTrace;

    try {
      await persistence.guard<void, _MappedFailure>(
        _throwFromOperation,
        _MappedFailure.new,
      );
    } on Object catch (error, stack) {
      caught = error;
      stackTrace = stack;
    }

    expect(caught, isA<_MappedFailure>());
    expect(stackTrace.toString(), contains('_throwFromOperation'));
  });
}

Future<void> _throwFromOperation() async {
  throw StateError('storage failure');
}

class _MappedFailure implements Exception {
  const _MappedFailure(this.cause);

  final Object cause;
}
