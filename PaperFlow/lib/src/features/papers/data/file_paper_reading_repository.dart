import '../../../core/storage/local_json_store.dart';
import '../domain/paper_reading_repository.dart';

class FilePaperReadingRepository implements PaperReadingRepository {
  FilePaperReadingRepository({LocalJsonStore? store})
      : _store = store ?? LocalJsonStore(fileName: 'paper_reading.json');

  final LocalJsonStore _store;

  @override
  Future<PaperReadingSnapshot> load() async {
    try {
      final json = await _store.read();
      if (json == null) return PaperReadingSnapshot();
      if (json is! Map<String, dynamic>) {
        throw const FormatException('Reading data must be an object.');
      }
      return PaperReadingSnapshot(
        readPaperIds: _stringList(json['readPaperIds']),
        readLaterPaperIds: _stringList(json['readLaterPaperIds']),
        historyPaperIds: _stringList(json['historyPaperIds']),
        tabIndices: _intMap(json['tabIndices']),
        abstractScrollOffsets: _doubleMap(json['abstractScrollOffsets']),
        dwellMilliseconds: _intMap(json['dwellMilliseconds']),
      );
    } catch (error) {
      throw PaperReadingPersistenceException('无法读取论文阅读状态。', error);
    }
  }

  @override
  Future<void> save(PaperReadingSnapshot snapshot) async {
    try {
      await _store.write({
        'readPaperIds': snapshot.readPaperIds.toList(),
        'readLaterPaperIds': snapshot.readLaterPaperIds.toList(),
        'historyPaperIds': snapshot.historyPaperIds,
        'tabIndices': snapshot.tabIndices,
        'abstractScrollOffsets': snapshot.abstractScrollOffsets,
        'dwellMilliseconds': snapshot.dwellMilliseconds,
      });
    } catch (error) {
      throw PaperReadingPersistenceException('无法保存论文阅读状态。', error);
    }
  }

  static List<String> _stringList(Object? value) => value is List
      ? value.whereType<String>().toList(growable: false)
      : const [];

  static Map<String, int> _intMap(Object? value) {
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries)
        if (entry.key is String && entry.value is int)
          entry.key as String: entry.value as int,
    };
  }

  static Map<String, double> _doubleMap(Object? value) {
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries)
        if (entry.key is String && entry.value is num)
          entry.key as String: (entry.value as num).toDouble(),
    };
  }
}
