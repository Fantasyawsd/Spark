import 'dart:math' as math;

import '../domain/behavior_event.dart';
import '../domain/user_profile.dart';

/// 论文元数据解析回调：返回主题、内容关键词与会议名称（可为空集合）。
typedef PaperProfileMetadata = ({
  Iterable<String> subjects,
  Iterable<String> keywords,
  String? venue,
});

/// 从行为事件聚合用户画像。纯函数：输入事件与元数据解析器，输出画像。
class ProfileAggregator {
  ProfileAggregator({
    DateTime Function()? clock,
    this.halfLife = const Duration(days: 30),
    this.openedWeight = 0.5,
    this.likedWeight = 2.0,
    this.savedWeight = 1.5,
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Duration halfLife;
  final double openedWeight;
  final double likedWeight;
  final double savedWeight;

  UserProfile aggregate(
    Iterable<BehaviorEvent> events, {
    required PaperProfileMetadata Function(String paperId) resolveMetadata,
    DateTime? asOf,
  }) {
    final now = asOf ?? _clock().toUtc();
    final subjects = <String, double>{};
    final keywords = <String, double>{};
    final venues = <String, double>{};

    void addWeight(Map<String, double> target, String? key, double weight) {
      if (key == null || key.trim().isEmpty) return;
      final normalized = key.trim();
      target[normalized] = (target[normalized] ?? 0) + weight;
    }

    for (final event in events) {
      final baseWeight = switch (event.type) {
        BehaviorEventType.paperOpened => openedWeight,
        BehaviorEventType.paperLiked => likedWeight,
        BehaviorEventType.paperSaved => savedWeight,
      };
      final decay = _decay(event.occurredAt.toUtc(), now);
      final weight = baseWeight * decay;
      if (weight <= 0) continue;
      final metadata = resolveMetadata(event.paperId);
      for (final subject in metadata.subjects) {
        addWeight(subjects, subject, weight);
      }
      for (final keyword in metadata.keywords) {
        addWeight(keywords, keyword, weight);
      }
      addWeight(venues, metadata.venue, weight);
    }

    return UserProfile(
      version: UserProfile.currentVersion,
      subjects: subjects,
      keywords: keywords,
      venues: venues,
      updatedAt: now,
    );
  }

  double _decay(DateTime occurredAt, DateTime asOf) {
    final ageSeconds =
        asOf.difference(occurredAt).inSeconds.clamp(0, 1 << 40);
    final halfLifeSeconds = halfLife.inSeconds;
    if (halfLifeSeconds <= 0) return 1.0;
    return math.pow(0.5, ageSeconds / halfLifeSeconds).toDouble();
  }
}
