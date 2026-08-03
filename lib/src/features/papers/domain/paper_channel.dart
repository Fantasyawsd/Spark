/// 用户可管理的频道类型。
///
/// `subject` 为 arXiv 分类频道；`conference` 为会议频道，在真实会议
/// 数据源就绪前不允许添加。
enum PaperChannelKind { subject, conference }

/// 用户添加的频道。固定频道（推荐 / 关注 / 最新）不属于用户频道。
class UserPaperChannel {
  const UserPaperChannel({
    required this.kind,
    required this.id,
    required this.displayName,
  });

  final PaperChannelKind kind;

  /// 主题频道为 arXiv 分类编号（如 `cs.AI`），会议频道为稳定来源 ID。
  final String id;

  final String displayName;

  String get storageKey => '${kind.name}:$id';
}

/// 论文页顶部频道栏的固定频道，顺序即展示顺序。
enum FixedPaperChannel { recommended, following, latest }
