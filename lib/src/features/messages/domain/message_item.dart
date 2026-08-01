enum MessageKind { direct, liked, commented, system }

class MessageItem {
  const MessageItem({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.kind,
    this.avatarUrl,
    this.unread = 0,
  });

  final String title;
  final String subtitle;
  final String time;
  final MessageKind kind;
  final String? avatarUrl;
  final int unread;
}
