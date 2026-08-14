/// 行为采集端口：papers 等业务模块通过该契约上报行为事件，
/// 不感知存储与同意门控实现。
abstract interface class BehaviorLogPort {
  Future<void> logPaperOpened(String paperId);

  Future<void> logPaperLiked(String paperId);

  Future<void> logPaperSaved(String paperId);
}
