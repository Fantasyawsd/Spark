import 'dart:io';

import '../../../core/storage/local_json_store.dart';
import '../domain/paper_search_history_repository.dart';

class FilePaperSearchHistoryRepository implements PaperSearchHistoryRepository {
  FilePaperSearchHistoryRepository({File? file})
      : _store = LocalJsonStore(fileName: 'search_history.json', file: file);

  final LocalJsonStore _store;

  @override
  Future<List<String>> load() async {
    try {
      final decoded = await _store.read();
      if (decoded == null) return const [];
      if (decoded is! List) {
        throw const FormatException('Search history must be a list.');
      }
      return decoded
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    } catch (error) {
      throw PaperSearchHistoryException('无法读取搜索历史。', error);
    }
  }

  @override
  Future<void> save(List<String> history) async {
    try {
      await _store.write(history);
    } catch (error) {
      throw PaperSearchHistoryException('无法保存搜索历史。', error);
    }
  }
}
