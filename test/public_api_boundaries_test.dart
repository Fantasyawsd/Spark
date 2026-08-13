import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public barrel does not expose data adapters or batch sync internals',
      () {
    final source = File('lib/spark.dart').readAsStringSync();

    expect(source, isNot(contains("/data/")));
    expect(source, isNot(contains('arxiv_oai_client.dart')));
    expect(source, isNot(contains('arxiv_jsonl_importer.dart')));
  });
}
