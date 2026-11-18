import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Umm al-Qura date with a user offset: the month start is decided by
/// moon sighting and can differ from the table by a day or two per country.
class HijriDate {
  static const maxAdjust = 2;
  static const _key = 'prayer_hijri_adj';

  static Future<int> loadAdjust() async =>
      (await SharedPreferences.getInstance()).getInt(_key) ?? 0;

  static Future<void> saveAdjust(int days) async =>
      (await SharedPreferences.getInstance())
          .setInt(_key, days.clamp(-maxAdjust, maxAdjust));

  /// e.g. "٨ جمادى الآخرة ١٤٤٨ هـ".
  static String format(DateTime day, {int adjust = 0}) {
    HijriCalendar.setLocal('ar');
    final h =
        HijriCalendar.fromDate(DateTime(day.year, day.month, day.day + adjust));
    return '${h.toFormat('dd MMMM yyyy')} هـ';
  }
}
