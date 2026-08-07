class PaperRecordCachePolicy {
  const PaperRecordCachePolicy({
    required this.ttl,
    required this.maxEntries,
  });

  final Duration ttl;
  final int maxEntries;

  void validate() {
    if (ttl <= Duration.zero) {
      throw ArgumentError.value(ttl, 'policy.ttl', 'must be positive');
    }
    if (maxEntries <= 0) {
      throw ArgumentError.value(
        maxEntries,
        'policy.maxEntries',
        'must be positive',
      );
    }
  }

  bool isExpired(DateTime timestamp, DateTime now) {
    return !now.toUtc().isBefore(timestamp.toUtc().add(ttl));
  }
}

typedef PaperRecordTimestampReader = DateTime Function(
  String recordId,
  Map<String, dynamic> json,
);

Map<String, dynamic> retainNewestPaperRecords(
  Map<String, dynamic> records, {
  required DateTime now,
  required PaperRecordCachePolicy policy,
  required PaperRecordTimestampReader timestampOf,
}) {
  policy.validate();
  final retained = <_TimestampedPaperRecord>[];
  for (final entry in records.entries) {
    final value = entry.value;
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Paper cache record must be an object.');
    }
    final timestamp = timestampOf(entry.key, value).toUtc();
    if (!policy.isExpired(timestamp, now)) {
      retained.add(
        _TimestampedPaperRecord(
          id: entry.key,
          json: value,
          timestamp: timestamp,
        ),
      );
    }
  }
  retained.sort((left, right) {
    final byTimestamp = right.timestamp.compareTo(left.timestamp);
    return byTimestamp != 0 ? byTimestamp : left.id.compareTo(right.id);
  });

  return {
    for (final record in retained.take(policy.maxEntries))
      record.id: record.json,
  };
}

class _TimestampedPaperRecord {
  const _TimestampedPaperRecord({
    required this.id,
    required this.json,
    required this.timestamp,
  });

  final String id;
  final Map<String, dynamic> json;
  final DateTime timestamp;
}
