import '../domain/favorite_group.dart';
import 'paper_json_value_reader.dart';
import 'paper_interaction_record.dart';

class PaperInteractionJsonMapper {
  const PaperInteractionJsonMapper._();

  static void validatePayload(Object? payload) {
    if (payload is! Map<String, dynamic>) {
      throw const FormatException(
        'Paper interaction payload must be an object.',
      );
    }
    PaperJsonValueReader.stringList(payload, 'likedPaperIds');
    PaperJsonValueReader.stringList(payload, 'followedPaperIds');
    PaperJsonValueReader.intMap(payload, 'shareCountDeltas');
    if (_usesGroupedFavorites(payload)) {
      final groups = _favoriteGroups(payload);
      final memberships = _favoriteMemberships(payload);
      final groupIds = groups.map((group) => group.id).toSet();
      if (!groupIds.contains(defaultFavoriteGroupId)) {
        throw const FormatException('Default favorite group is required.');
      }
      if (memberships.keys.any((groupId) => !groupIds.contains(groupId))) {
        throw const FormatException(
          'Favorite memberships must reference an existing group.',
        );
      }
    } else {
      PaperJsonValueReader.stringList(payload, 'savedPaperIds');
    }
  }

  static Object? migrateV1ToV2(Object? payload) {
    if (payload is! Map<String, dynamic>) {
      throw const FormatException(
        'Paper interaction payload must be an object.',
      );
    }
    PaperJsonValueReader.stringList(payload, 'likedPaperIds');
    final savedPaperIds = PaperJsonValueReader.stringList(
      payload,
      'savedPaperIds',
    );
    PaperJsonValueReader.stringList(payload, 'followedPaperIds');
    PaperJsonValueReader.intMap(payload, 'shareCountDeltas');
    return {
      'likedPaperIds': PaperJsonValueReader.stringList(
        payload,
        'likedPaperIds',
      ),
      'favoriteGroups': [
        {'id': defaultFavoriteGroupId, 'name': '默认收藏'},
      ],
      'favoritePaperIdsByGroup': {defaultFavoriteGroupId: savedPaperIds},
      'followedPaperIds': PaperJsonValueReader.stringList(
        payload,
        'followedPaperIds',
      ),
      'shareCountDeltas': PaperJsonValueReader.intMap(
        payload,
        'shareCountDeltas',
      ),
    };
  }

  static PaperInteractionRecord fromJson(Map<String, dynamic> json) {
    if (!_usesGroupedFavorites(json)) {
      return PaperInteractionRecord(
        likedPaperIds: PaperJsonValueReader.stringList(json, 'likedPaperIds'),
        savedPaperIds: PaperJsonValueReader.stringList(json, 'savedPaperIds'),
        followedPaperIds: PaperJsonValueReader.stringList(
          json,
          'followedPaperIds',
        ),
        shareCountDeltas: PaperJsonValueReader.intMap(json, 'shareCountDeltas'),
      );
    }
    return PaperInteractionRecord(
      likedPaperIds: PaperJsonValueReader.stringList(json, 'likedPaperIds'),
      favoriteGroups: _favoriteGroups(json),
      favoritePaperIdsByGroup: _favoriteMemberships(json),
      followedPaperIds: PaperJsonValueReader.stringList(
        json,
        'followedPaperIds',
      ),
      shareCountDeltas: PaperJsonValueReader.intMap(json, 'shareCountDeltas'),
    );
  }

  static Map<String, dynamic> toJson(PaperInteractionRecord snapshot) {
    return {
      'likedPaperIds': snapshot.likedPaperIds.toList(),
      'favoriteGroups': snapshot.favoriteGroups
          .map((group) => {'id': group.id, 'name': group.name})
          .toList(growable: false),
      'favoritePaperIdsByGroup': {
        for (final entry in snapshot.favoritePaperIdsByGroup.entries)
          entry.key: entry.value.toList(),
      },
      'followedPaperIds': snapshot.followedPaperIds.toList(),
      'shareCountDeltas': snapshot.shareCountDeltas,
    };
  }

  static bool _usesGroupedFavorites(Map<String, dynamic> json) =>
      json.containsKey('favoriteGroups') ||
      json.containsKey('favoritePaperIdsByGroup');

  static List<FavoriteGroup> _favoriteGroups(Map<String, dynamic> json) {
    final value = json['favoriteGroups'];
    if (value is! List) {
      throw const FormatException('favoriteGroups must be a list.');
    }
    final groups = <FavoriteGroup>[];
    final ids = <String>{};
    for (final item in value) {
      if (item is! Map || item['id'] is! String || item['name'] is! String) {
        throw const FormatException('Favorite group record is invalid.');
      }
      final id = item['id'] as String;
      final name = item['name'] as String;
      if (id.trim().isEmpty || name.trim().isEmpty || !ids.add(id)) {
        throw const FormatException('Favorite group identity is invalid.');
      }
      groups.add(FavoriteGroup(id: id, name: name));
    }
    return groups;
  }

  static Map<String, Iterable<String>> _favoriteMemberships(
    Map<String, dynamic> json,
  ) {
    final value = json['favoritePaperIdsByGroup'];
    if (value is! Map) {
      throw const FormatException('favoritePaperIdsByGroup must be an object.');
    }
    final result = <String, Iterable<String>>{};
    for (final entry in value.entries) {
      if (entry.key is! String || entry.value is! List) {
        throw const FormatException('Favorite memberships are invalid.');
      }
      final paperIds = entry.value as List;
      if (paperIds.any((paperId) => paperId is! String)) {
        throw const FormatException('Favorite paper IDs must be strings.');
      }
      result[entry.key as String] = paperIds.cast<String>();
    }
    return result;
  }
}
