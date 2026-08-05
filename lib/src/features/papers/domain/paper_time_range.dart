import 'paper.dart';

/// 发布时间筛选。日期均按本地日历输入，边界转换在查询层完成。
sealed class PaperTimeRange {
  const PaperTimeRange();

  const factory PaperTimeRange.all() = AllPaperTimeRange;
  const factory PaperTimeRange.latestDay() = LatestDayPaperTimeRange;
  const factory PaperTimeRange.last7Days() = Last7DaysPaperTimeRange;
  const factory PaperTimeRange.last30Days() = Last30DaysPaperTimeRange;
  const factory PaperTimeRange.date(DateTime date) = DatePaperTimeRange;
  factory PaperTimeRange.range(DateTime from, DateTime until) =
      CustomPaperTimeRange;

  String get storageKey;
  String get label;
  bool includes(Paper paper, {required DateTime now});
  PaperDateBounds? bounds({required DateTime now}) => null;

  static PaperTimeRange fromStorageKey(String? value) {
    if (value == null || value == 'all') return const PaperTimeRange.all();
    if (value == 'latest-day') return const PaperTimeRange.latestDay();
    if (value == 'last-7-days') return const PaperTimeRange.last7Days();
    if (value == 'last-30-days') return const PaperTimeRange.last30Days();
    if (value.startsWith('date:')) {
      final date = DateTime.tryParse(value.substring(5));
      if (date != null) return PaperTimeRange.date(date);
    }
    if (value.startsWith('range:')) {
      final parts = value.substring(6).split('|');
      if (parts.length == 2) {
        final from = DateTime.tryParse(parts[0]);
        final until = DateTime.tryParse(parts[1]);
        if (from != null && until != null) {
          return PaperTimeRange.range(from, until);
        }
      }
    }
    return const PaperTimeRange.all();
  }

  static DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime _endOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day, 23, 59, 59, 999);

  static bool _contains(Paper paper, PaperDateBounds range) {
    final publishedAt = paper.publishedAt?.toLocal();
    return publishedAt != null &&
        !publishedAt.isBefore(range.start) &&
        !publishedAt.isAfter(range.end);
  }
}

class AllPaperTimeRange extends PaperTimeRange {
  const AllPaperTimeRange();
  @override
  String get storageKey => 'all';
  @override
  String get label => '不限时间';
  @override
  bool includes(Paper paper, {required DateTime now}) => true;
}

class LatestDayPaperTimeRange extends PaperTimeRange {
  const LatestDayPaperTimeRange();
  @override
  String get storageKey => 'latest-day';
  @override
  String get label => '最新发布日';
  @override
  bool includes(Paper paper, {required DateTime now}) =>
      PaperTimeRange._contains(paper, bounds(now: now));
  @override
  PaperDateBounds bounds({required DateTime now}) => PaperDateBounds(
        start: PaperTimeRange._startOfDay(now),
        end: PaperTimeRange._endOfDay(now),
      );
}

class Last7DaysPaperTimeRange extends PaperTimeRange {
  const Last7DaysPaperTimeRange();
  @override
  String get storageKey => 'last-7-days';
  @override
  String get label => '最近 7 天';
  @override
  bool includes(Paper paper, {required DateTime now}) =>
      PaperTimeRange._contains(paper, bounds(now: now));
  @override
  PaperDateBounds bounds({required DateTime now}) => PaperDateBounds(
        start:
            PaperTimeRange._startOfDay(now.subtract(const Duration(days: 6))),
        end: PaperTimeRange._endOfDay(now),
      );
}

class Last30DaysPaperTimeRange extends PaperTimeRange {
  const Last30DaysPaperTimeRange();
  @override
  String get storageKey => 'last-30-days';
  @override
  String get label => '最近 30 天';
  @override
  bool includes(Paper paper, {required DateTime now}) =>
      PaperTimeRange._contains(paper, bounds(now: now));
  @override
  PaperDateBounds bounds({required DateTime now}) => PaperDateBounds(
        start:
            PaperTimeRange._startOfDay(now.subtract(const Duration(days: 29))),
        end: PaperTimeRange._endOfDay(now),
      );
}

class DatePaperTimeRange extends PaperTimeRange {
  const DatePaperTimeRange(this.date);
  final DateTime date;
  @override
  String get storageKey => 'date:${_dateKey(date)}';
  @override
  String get label => '${date.year} 年 ${date.month} 月 ${date.day} 日';
  @override
  bool includes(Paper paper, {required DateTime now}) =>
      PaperTimeRange._contains(paper, bounds(now: now));
  @override
  PaperDateBounds bounds({required DateTime now}) => PaperDateBounds(
        start: PaperTimeRange._startOfDay(date),
        end: PaperTimeRange._endOfDay(date),
      );
}

class CustomPaperTimeRange extends PaperTimeRange {
  CustomPaperTimeRange(DateTime from, DateTime until)
      : from = from.isAfter(until) ? until : from,
        until = from.isAfter(until) ? from : until;
  final DateTime from;
  final DateTime until;
  @override
  String get storageKey => 'range:${_dateKey(from)}|${_dateKey(until)}';
  @override
  String get label => '${from.month}/${from.day} - ${until.month}/${until.day}';
  @override
  bool includes(Paper paper, {required DateTime now}) =>
      PaperTimeRange._contains(paper, bounds(now: now));
  @override
  PaperDateBounds bounds({required DateTime now}) => PaperDateBounds(
        start: PaperTimeRange._startOfDay(from),
        end: PaperTimeRange._endOfDay(until),
      );
}

class PaperDateBounds {
  const PaperDateBounds({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

String _dateKey(DateTime date) =>
    DateTime(date.year, date.month, date.day).toIso8601String();
