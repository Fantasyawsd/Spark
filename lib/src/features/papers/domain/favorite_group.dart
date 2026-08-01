const defaultFavoriteGroupId = 'default';

class FavoriteGroup {
  const FavoriteGroup({required this.id, required this.name});

  const FavoriteGroup.defaultGroup()
      : id = defaultFavoriteGroupId,
        name = '默认收藏';

  final String id;
  final String name;

  bool get isDefault => id == defaultFavoriteGroupId;
}
