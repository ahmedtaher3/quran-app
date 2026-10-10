import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const totalPages = 604;

/// One active khatma, stored as JSON in prefs. Progress is page-based:
/// [currentPage] is the next page to read.
class Khatma {
  final int days;
  final DateTime start;
  final int currentPage;
  final int? reminderHour;
  final int? reminderMinute;

  Khatma({
    required this.days,
    required this.start,
    this.currentPage = 1,
    this.reminderHour,
    this.reminderMinute,
  });

  int get dailyPages => (totalPages / days).ceil();
  int get pagesDone => currentPage - 1;
  double get progress => pagesDone / totalPages;
  bool get finished => currentPage > totalPages;

  int get wirdStart => currentPage;
  int get wirdEnd => (currentPage + dailyPages - 1).clamp(1, totalPages);

  /// 1-based day number since start (today counts).
  int dayNumber(DateTime now) =>
      // utc dates: a 23h DST day would otherwise truncate to 0 days
      DateTime.utc(now.year, now.month, now.day)
          .difference(DateTime.utc(start.year, start.month, start.day))
          .inDays +
      1;

  /// Positive = pages behind schedule, negative = ahead.
  /// Today's wird isn't overdue yet, so only past days count.
  int pagesBehind(DateTime now) {
    final expected = ((dayNumber(now) - 1) * dailyPages).clamp(0, totalPages);
    return expected - pagesDone;
  }

  bool doneToday(DateTime now) =>
      pagesDone >= (dayNumber(now) * dailyPages).clamp(0, totalPages);

  int daysLeft(DateTime now) => (days - dayNumber(now) + 1).clamp(0, days);

  Khatma copyWith({int? currentPage, int? reminderHour, int? reminderMinute,
      bool clearReminder = false}) {
    return Khatma(
      days: days,
      start: start,
      currentPage: currentPage ?? this.currentPage,
      reminderHour: clearReminder ? null : reminderHour ?? this.reminderHour,
      reminderMinute:
          clearReminder ? null : reminderMinute ?? this.reminderMinute,
    );
  }

  Map<String, dynamic> toJson() => {
        'days': days,
        'start': start.millisecondsSinceEpoch,
        'currentPage': currentPage,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
      };

  factory Khatma.fromJson(Map<String, dynamic> j) => Khatma(
        days: j['days'],
        start: DateTime.fromMillisecondsSinceEpoch(j['start']),
        currentPage: j['currentPage'],
        reminderHour: j['reminderHour'],
        reminderMinute: j['reminderMinute'],
      );
}

class KhatmaStore {
  static const _key = 'khatma';
  static const _doneKey = 'khatma_completed_count';

  static Future<Khatma?> load() async {
    final s = (await SharedPreferences.getInstance()).getString(_key);
    return s == null ? null : Khatma.fromJson(jsonDecode(s));
  }

  static Future<void> save(Khatma k) async {
    await (await SharedPreferences.getInstance())
        .setString(_key, jsonEncode(k.toJson()));
  }

  static Future<void> clear() async {
    await (await SharedPreferences.getInstance()).remove(_key);
  }

  static Future<int> completedCount() async =>
      (await SharedPreferences.getInstance()).getInt(_doneKey) ?? 0;

  static Future<void> incrementCompleted() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_doneKey, (p.getInt(_doneKey) ?? 0) + 1);
  }
}
