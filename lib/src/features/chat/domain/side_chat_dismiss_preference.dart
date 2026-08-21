/// side chat「不再显示」提示的持久化抽象。
abstract interface class SideChatDismissPreference {
  Future<bool> load();

  Future<void> save(bool suppress);
}
