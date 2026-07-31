import '../../../core/storage/local_json_store.dart';
import '../domain/paper_interaction_repository.dart';

class FilePaperInteractionRepository implements PaperInteractionRepository {
  FilePaperInteractionRepository({LocalJsonStore? store})
      : _store = store ?? LocalJsonStore(fileName: 'paper_interactions.json');

  final LocalJsonStore _store;

  @override
  Future<PaperInteractionSnapshot> load() async {
    try {
      final json = await _store.read();
      if (json == null) return PaperInteractionSnapshot();
      if (json is! Map<String, dynamic>) {
        throw const FormatException('Interaction data must be an object.');
      }
      return PaperInteractionSnapshot(
        likedPaperIds: _stringList(json['likedPaperIds']),
        savedPaperIds: _stringList(json['savedPaperIds']),
        followedPaperIds: _stringList(json['followedPaperIds']),
        shareCountDeltas: _intMap(json['shareCountDeltas']),
      );
    } catch (error) {
      throw PaperInteractionPersistenceException('无法读取论文互动状态。', error);
    }
  }

  @override
  Future<void> save(PaperInteractionSnapshot snapshot) async {
    try {
      await _store.write({
        'likedPaperIds': snapshot.likedPaperIds.toList(),
        'savedPaperIds': snapshot.savedPaperIds.toList(),
        'followedPaperIds': snapshot.followedPaperIds.toList(),
        'shareCountDeltas': snapshot.shareCountDeltas,
      });
    } catch (error) {
      throw PaperInteractionPersistenceException('无法保存论文互动状态。', error);
    }
  }

  static Map<String, int> _intMap(Object? value) {
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries)
        if (entry.key is String && entry.value is int)
          entry.key as String: entry.value as int,
    };
  }

  static List<String> _stringList(Object? value) => value is List
      ? value.whereType<String>().toList(growable: false)
      : const [];
}
