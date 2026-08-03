import 'paper_channel.dart';

/// 用户的频道配置；列表顺序即频道栏展示顺序（固定频道之后）。
class PaperChannelPreferences {
  PaperChannelPreferences({
    Iterable<UserPaperChannel> userChannels = const [],
  }) : userChannels = List.unmodifiable(userChannels);

  final List<UserPaperChannel> userChannels;
}

abstract interface class PaperChannelPreferenceRepository {
  Future<PaperChannelPreferences> load();

  Future<void> save(PaperChannelPreferences preferences);
}

class PaperChannelPreferencePersistenceException implements Exception {
  const PaperChannelPreferencePersistenceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
