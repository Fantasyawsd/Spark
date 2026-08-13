import '../domain/favorite_group.dart';
import '../domain/paper_interaction_repository.dart';

/// Persistence-shaped representation of interaction state.
class PaperInteractionRecord {
  const PaperInteractionRecord({
    required this.likedPaperIds,
    this.savedPaperIds = const [],
    this.favoriteGroups = const [],
    this.favoritePaperIdsByGroup = const {},
    required this.followedPaperIds,
    required this.shareCountDeltas,
  });

  factory PaperInteractionRecord.fromDomain(PaperInteractionSnapshot snapshot) {
    return PaperInteractionRecord(
      likedPaperIds: snapshot.likedPaperIds,
      favoriteGroups: snapshot.favoriteGroups,
      favoritePaperIdsByGroup: snapshot.favoritePaperIdsByGroup,
      followedPaperIds: snapshot.followedPaperIds,
      shareCountDeltas: snapshot.shareCountDeltas,
    );
  }

  final Iterable<String> likedPaperIds;
  final Iterable<String> savedPaperIds;
  final Iterable<FavoriteGroup> favoriteGroups;
  final Map<String, Iterable<String>> favoritePaperIdsByGroup;
  final Iterable<String> followedPaperIds;
  final Map<String, int> shareCountDeltas;

  PaperInteractionSnapshot toDomain() {
    return PaperInteractionSnapshot(
      likedPaperIds: likedPaperIds,
      savedPaperIds: savedPaperIds,
      favoriteGroups: favoriteGroups,
      favoritePaperIdsByGroup: favoritePaperIdsByGroup,
      followedPaperIds: followedPaperIds,
      shareCountDeltas: shareCountDeltas,
    );
  }
}
