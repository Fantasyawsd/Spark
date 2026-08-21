import '../../../core/storage/local_json_store.dart';

/// side chat 返回提示的“不再显示”偏好。
///
/// 仅持久化一个 bool，不保存任何会话内容。
class SideChatDismissPreferenceStore {
  SideChatDismissPreferenceStore({LocalJsonStore? store})
      : _store =
            store ?? LocalJsonStore(fileName: 'side_chat_preferences.json');

  final LocalJsonStore _store;

  static const String _key = 'suppressSideChatDismissTip';

  Future<bool> load() async {
    final raw = await _store.read();
    if (raw is Map) {
      final value = raw[_key];
      if (value is bool) return value;
    }
    return false;
  }

  Future<void> save(bool suppress) async {
    await _store.write({_key: suppress});
  }
}
