import '../domain/paper_channel.dart';
import '../domain/paper_channel_preference_repository.dart';

class PaperChannelPreferenceJsonMapper {
  const PaperChannelPreferenceJsonMapper._();

  static void validatePayload(Object? payload) {
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('频道偏好必须是对象。');
    }
    fromJson(payload);
  }

  static PaperChannelPreferences fromJson(Map<String, dynamic> json) {
    return PaperChannelPreferences(
      userChannels: _channels(json),
    );
  }

  static Map<String, dynamic> toJson(PaperChannelPreferences preferences) {
    return {
      'userChannels': preferences.userChannels
          .map(
            (channel) => {
              'kind': channel.kind.name,
              'id': channel.id,
              'displayName': channel.displayName,
            },
          )
          .toList(growable: false),
    };
  }

  static List<UserPaperChannel> _channels(Map<String, dynamic> json) {
    final value = json['userChannels'];
    if (value == null) return const [];
    if (value is! List) {
      throw const FormatException('频道偏好 userChannels 必须是数组。');
    }
    return value.map((item) {
      if (item is! Map) {
        throw const FormatException('频道偏好条目必须是对象。');
      }
      final channel = Map<String, dynamic>.from(item);
      return UserPaperChannel(
        kind: _kind(channel),
        id: _requiredString(channel, 'id'),
        displayName: _requiredString(channel, 'displayName'),
      );
    }).toList(growable: false);
  }

  static PaperChannelKind _kind(Map<String, dynamic> channel) {
    final value = channel['kind'];
    if (value is! String) {
      throw const FormatException('频道偏好 kind 必须是字符串。');
    }
    final kind = PaperChannelKind.values
        .where((candidate) => candidate.name == value)
        .firstOrNull;
    if (kind == null) {
      throw FormatException('未知的频道类型：$value');
    }
    return kind;
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('频道偏好字段 $key 必须是非空字符串。');
    }
    return value;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
