import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled/core/notifications.dart';
import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';
import 'package:untitled/features/Koran/data/model/ayah.dart';

const _totalAyat = 6236;

/// Same ayah for everyone on a given date; stable across launches.
int ayahIdFor(DateTime d) {
  // days since epoch times a large odd multiplier, so consecutive days
  // land far apart in the mushaf
  final day = DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
  return (day * 2654435761) % _totalAyat + 1;
}

Future<Verse?> ayahOfDay([DateTime? d]) =>
    DBHelper.getVerseById(ayahIdFor(d ?? DateTime.now()));

class DailyAyahPrefs {
  static const _on = 'daily_ayah_on', _hour = 'daily_ayah_hour';

  static Future<(bool, int)> load() async {
    final p = await SharedPreferences.getInstance();
    return (p.getBool(_on) ?? false, p.getInt(_hour) ?? 8);
  }

  static Future<void> save(bool on, int hour) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_on, on);
    await p.setInt(_hour, hour);
    await reschedule();
  }

  /// Re-plans the next 7 days; called on app start and when prefs change.
  static Future<void> reschedule() async {
    final (on, hour) = await load();
    for (var i = 0; i < 7; i++) {
      await Notifications.cancel(Notifications.dailyAyahBaseId + i);
    }
    if (!on) return;
    final now = DateTime.now();
    for (var i = 0; i < 7; i++) {
      final day = DateTime(now.year, now.month, now.day + i);
      final v = await ayahOfDay(day);
      if (v == null) continue;
      await Notifications.scheduleAt(
        id: Notifications.dailyAyahBaseId + i,
        at: DateTime(day.year, day.month, day.day, hour),
        title: "آية اليوم • ${v.suraName ?? ''} ${v.ayaNumber}",
        body: v.text,
      );
    }
  }
}
