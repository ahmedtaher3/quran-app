import 'package:flutter/material.dart';

String _key(DateTime d) =>
    "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

DateTime _prev(DateTime d) => DateTime(d.year, d.month, d.day - 1);

/// Days in a row ending today — or yesterday, so the streak isn't shown as
/// broken before the user has had a chance to read today.
int currentStreak(Set<String> days, DateTime today) {
  var d = DateTime(today.year, today.month, today.day);
  if (!days.contains(_key(d))) d = _prev(d);
  var n = 0;
  while (days.contains(_key(d))) {
    n++;
    d = _prev(d);
  }
  return n;
}

int longestStreak(Set<String> days) {
  var best = 0;
  for (final k in days) {
    final d = DateTime.parse(k);
    if (days.contains(_key(_prev(d)))) continue; // not a run start
    var n = 0;
    var c = d;
    while (days.contains(_key(c))) {
      n++;
      c = DateTime(c.year, c.month, c.day + 1);
    }
    if (n > best) best = n;
  }
  return best;
}

/// Verses per day for the last [n] days, oldest first.
List<({DateTime day, int verses})> lastDays(
    Map<String, int> perDay, DateTime today, int n) {
  return [
    for (var i = n - 1; i >= 0; i--)
      () {
        final d = DateTime(today.year, today.month, today.day - i);
        return (day: d, verses: perDay[_key(d)] ?? 0);
      }(),
  ];
}

class Achievement {
  final String title;
  final String hint;
  final IconData icon;
  final bool earned;
  const Achievement(this.title, this.hint, this.icon, this.earned);
}

List<Achievement> achievements({
  required int totalVerses,
  required int suras,
  required int longest,
  required int khatmas,
}) =>
    [
      Achievement("البداية", "اقرأ أول آية", Icons.flag_rounded, totalVerses > 0),
      Achievement("أسبوع متواصل", "7 أيام متتالية", Icons.local_fire_department_rounded,
          longest >= 7),
      Achievement("شهر متواصل", "30 يومًا متتالية", Icons.whatshot_rounded,
          longest >= 30),
      Achievement("ألف آية", "اقرأ 1000 آية", Icons.menu_book_rounded,
          totalVerses >= 1000),
      Achievement("جميع السور", "اقرأ من كل السور الـ114", Icons.auto_awesome_rounded,
          suras >= 114),
      Achievement("الختمة الأولى", "أتمّ ختمة كاملة", Icons.emoji_events_rounded,
          khatmas > 0),
    ];
