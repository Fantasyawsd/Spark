import 'dart:io';

import '../../../core/storage/local_json_store.dart';
import '../../../core/storage/versioned_local_json_store.dart';
import '../domain/paper_search_history_repository.dart';
import 'paper_search_history_json_mapper.dart';

class FilePaperSearchHistoryRepository implements PaperSearchHistoryRepository {
  FilePaperSearchHistoryRepository({LocalJsonStore? store, File? file})
      : assert(store == null || file == null),
        _store = VersionedLocalJsonStore(
          store ?? LocalJsonStore(fileName: 'search_history.json', file: file),
          schemaId: 'search.history',
          validatePayload: PaperSearchHistoryJsonMapper.validatePayload,
        );

  final VersionedLocalJsonStore _store;

  @override
  Future<List<String>> load() async {
    try {
      final decoded = await _store.readList();
      if (decoded == null) return const [];
      return PaperSearchHistoryJsonMapper.fromJson(decoded);
    } catch (error) {
      throw PaperSearchHistoryException('无法读取搜索历史。', error);
    }
  }

  @override
  Future<void> save(List<String> history) async {
    try {
      await _store.writeList(history);
    } catch (error) {
      throw PaperSearchHistoryException('无法保存搜索历史。', error);
    }
  }
}
