import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/papers/data/paper_json_value_reader.dart';

void main() {
  test('reads nullable primitive collections with stable defaults', () {
    expect(
      PaperJsonValueReader.stringList(const {}, 'items'),
      isEmpty,
    );
    expect(PaperJsonValueReader.intMap(const {}, 'counts'), isEmpty);
    expect(PaperJsonValueReader.stringMap(const {}, 'labels'), isEmpty);
    expect(PaperJsonValueReader.doubleMap(const {}, 'offsets'), isEmpty);
    expect(PaperJsonValueReader.optionalInt(const {}, 'index'), 0);
  });

  test('converts numeric maps to doubles without losing values', () {
    expect(
      PaperJsonValueReader.doubleMap(
        {
          'offsets': {'paper-1': 12, 'paper-2': 2.5}
        },
        'offsets',
      ),
      {'paper-1': 12.0, 'paper-2': 2.5},
    );
  });

  test('rejects values with an incompatible primitive shape', () {
    expect(
      () => PaperJsonValueReader.stringList({
        'items': [1]
      }, 'items'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => PaperJsonValueReader.intMap({
        'counts': {'paper-1': '1'}
      }, 'counts'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => PaperJsonValueReader.optionalInt({'index': 1.5}, 'index'),
      throwsA(isA<FormatException>()),
    );
  });
}
