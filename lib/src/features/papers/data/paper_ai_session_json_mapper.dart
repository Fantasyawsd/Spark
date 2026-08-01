import '../../chat/domain/chat_message.dart';

class PaperAiSessionJsonMapper {
  const PaperAiSessionJsonMapper._();

  static void validatePayload(Object? payload) {
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('AI session payload must be an object.');
    }
    for (final entry in payload.entries) {
      final session = entry.value;
      final messages = rawMessages(session);
      if (messages is! List) {
        throw FormatException('AI session ${entry.key} must contain messages.');
      }
      if (session is Map) _validateSessionMetadata(session);
      for (final message in messages) {
        fromJson(_stringMap(message, 'AI message'));
      }
    }
  }

  static Object? rawMessages(Object? session) {
    return session is Map ? session['messages'] : session;
  }

  static List<ChatMessage> messagesFor(
    Map<String, dynamic> json,
    String contextId,
  ) {
    final messages = rawMessages(json[contextId]);
    if (messages == null) return const [];
    if (messages is! List) {
      throw FormatException('AI session $contextId must contain messages.');
    }
    return messages
        .map((raw) => fromJson(_stringMap(raw, 'AI message')))
        .where(hasPersistableContent)
        .toList(growable: false);
  }

  static ChatMessage fromJson(Map<String, dynamic> raw) {
    final fromUser = raw['fromUser'];
    if (fromUser is! bool) {
      throw const FormatException('fromUser must be a boolean.');
    }
    return ChatMessage(
      fromUser: fromUser,
      content: _optionalString(raw, 'content'),
      reasoningContent: _optionalString(raw, 'reasoningContent'),
      sources: _sourcesFromJson(raw['sources']),
      status: _statusFromJson(raw['status']),
    );
  }

  static Map<String, Object> toJson(ChatMessage message) {
    return {
      'fromUser': message.fromUser,
      'content': message.content,
      'reasoningContent': message.reasoningContent,
      'status': message.status.name,
      'sources': [
        for (final source in message.sources)
          {'title': source.title, 'url': source.url},
      ],
    };
  }

  static bool hasPersistableContent(ChatMessage message) {
    return message.content.trim().isNotEmpty ||
        message.reasoningContent.trim().isNotEmpty ||
        message.sources.isNotEmpty ||
        message.status != ChatMessageStatus.complete;
  }

  static bool isPinned(Object? session) {
    if (session is! Map) return false;
    final pinned = session['pinned'];
    if (pinned == null) return false;
    if (pinned is! bool) {
      throw const FormatException('pinned must be a boolean.');
    }
    return pinned;
  }

  static DateTime updatedAt(Object? session) {
    if (session is! Map) return DateTime.fromMillisecondsSinceEpoch(0);
    final raw = session['updatedAt'];
    if (raw == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (raw is! String || DateTime.tryParse(raw) == null) {
      throw const FormatException('updatedAt must be an ISO-8601 string.');
    }
    return DateTime.parse(raw);
  }

  static void _validateSessionMetadata(Map session) {
    isPinned(session);
    updatedAt(session);
  }

  static ChatMessageStatus _statusFromJson(Object? rawStatus) {
    if (rawStatus == null) return ChatMessageStatus.complete;
    if (rawStatus is! String) {
      throw const FormatException('status must be a string.');
    }
    for (final status in ChatMessageStatus.values) {
      if (status.name == rawStatus) return status;
    }
    throw FormatException('Unknown AI message status: $rawStatus.');
  }

  static List<ChatSource> _sourcesFromJson(Object? rawSources) {
    if (rawSources == null) return const [];
    if (rawSources is! List) {
      throw const FormatException('sources must be a list.');
    }
    return rawSources.map((raw) {
      final source = _stringMap(raw, 'AI source');
      return ChatSource(
        title: _requiredString(source, 'title'),
        url: _requiredString(source, 'url'),
      );
    }).toList(growable: false);
  }

  static Map<String, dynamic> _stringMap(Object? value, String label) {
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw FormatException('$label must be an object.');
    }
    return Map<String, dynamic>.from(value);
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String) throw FormatException('$key must be a string.');
    return value;
  }

  static String _optionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return '';
    if (value is! String) throw FormatException('$key must be a string.');
    return value;
  }
}
