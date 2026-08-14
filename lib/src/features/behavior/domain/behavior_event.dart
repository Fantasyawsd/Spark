enum BehaviorEventType { paperOpened, paperLiked, paperSaved }

class BehaviorEvent {
  BehaviorEvent({
    required this.type,
    required this.paperId,
    required this.occurredAt,
    Map<String, String> context = const {},
  })  : assert(paperId.trim().isNotEmpty, 'paperId must not be empty'),
        context = Map.unmodifiable(context);

  factory BehaviorEvent.fromJson(Map<String, dynamic> json) {
    final type = BehaviorEventType.values.firstWhere(
      (value) => value.name == json['type'],
      orElse: () => throw const FormatException('unknown behavior event type'),
    );
    final rawContext = json['context'];
    if (rawContext is! Map) {
      throw const FormatException('behavior event context must be an object');
    }
    return BehaviorEvent(
      type: type,
      paperId: json['paper_id'] as String,
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      context: rawContext.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
    );
  }

  final BehaviorEventType type;
  final String paperId;
  final DateTime occurredAt;
  final Map<String, String> context;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'paper_id': paperId,
        'occurred_at': occurredAt.toIso8601String(),
        'context': context,
      };
}
