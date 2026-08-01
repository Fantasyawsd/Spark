import 'favorite_group.dart';

class PaperInteractionSnapshot {
  PaperInteractionSnapshot({
    Iterable<String> likedPaperIds = const [],
    Iterable<String> savedPaperIds = const [],
    Iterable<FavoriteGroup> favoriteGroups = const [],
    Map<String, Iterable<String>> favoritePaperIdsByGroup = const {},
    Iterable<String> followedPaperIds = const [],
    Map<String, int> shareCountDeltas = const {},
  })  : likedPaperIds = Set.unmodifiable(likedPaperIds),
        followedPaperIds = Set.unmodifiable(followedPaperIds),
        shareCountDeltas = Map.unmodifiable(shareCountDeltas) {
    final groupsById = <String, FavoriteGroup>{
      defaultFavoriteGroupId: const FavoriteGroup.defaultGroup(),
      for (final group in favoriteGroups)
        if (!group.isDefault &&
            group.id.trim().isNotEmpty &&
            group.name.trim().isNotEmpty)
          group.id: FavoriteGroup(id: group.id, name: group.name.trim()),
    };
    final memberships = <String, Set<String>>{
      for (final groupId in groupsById.keys)
        groupId: {...?favoritePaperIdsByGroup[groupId]},
    };
    memberships[defaultFavoriteGroupId]!.addAll(savedPaperIds);
    this.favoriteGroups = List.unmodifiable(groupsById.values);
    this.favoritePaperIdsByGroup = Map.unmodifiable({
      for (final entry in memberships.entries)
        entry.key: Set.unmodifiable(entry.value),
    });
    this.savedPaperIds = Set.unmodifiable(
      memberships.values.expand((paperIds) => paperIds),
    );
  }

  final Set<String> likedPaperIds;
  late final Set<String> savedPaperIds;
  late final List<FavoriteGroup> favoriteGroups;
  late final Map<String, Set<String>> favoritePaperIdsByGroup;
  final Set<String> followedPaperIds;
  final Map<String, int> shareCountDeltas;
}

abstract interface class PaperInteractionRepository {
  Future<PaperInteractionSnapshot> load();

  Future<void> save(PaperInteractionSnapshot snapshot);
}

class PaperInteractionPersistenceException implements Exception {
  const PaperInteractionPersistenceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
