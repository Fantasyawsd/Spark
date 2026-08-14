/// 版本化用户画像：从设备本地行为事件聚合的偏好权重。
/// 权重越大表示偏好越强；负权重表示负偏好（4.2 暂只聚合正信号，负信号留后续）。
class UserProfile {
  UserProfile({
    required this.version,
    required Map<String, double> subjects,
    required Map<String, double> keywords,
    required Map<String, double> venues,
    required this.updatedAt,
  })  : subjects = Map.unmodifiable(subjects),
        keywords = Map.unmodifiable(keywords),
        venues = Map.unmodifiable(venues);

  static const String currentVersion = 'profile.v1';

  factory UserProfile.empty({required DateTime updatedAt}) => UserProfile(
        version: currentVersion,
        subjects: const {},
        keywords: const {},
        venues: const {},
        updatedAt: updatedAt,
      );

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      version: json['version'] as String,
      subjects: _weightMap(json['subjects']),
      keywords: _weightMap(json['keywords']),
      venues: _weightMap(json['venues']),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String version;
  final Map<String, double> subjects;
  final Map<String, double> keywords;
  final Map<String, double> venues;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'version': version,
        'subjects': subjects,
        'keywords': keywords,
        'venues': venues,
        'updated_at': updatedAt.toIso8601String(),
      };

  static Map<String, double> _weightMap(Object? value) {
    if (value is! Map) return const {};
    final result = <String, double>{};
    for (final entry in value.entries) {
      final key = entry.key.toString().trim();
      final weight = entry.value;
      if (key.isEmpty || weight is! num) continue;
      result[key] = weight.toDouble();
    }
    return result;
  }
}
