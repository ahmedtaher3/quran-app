import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Umm al-Qura date with a user offset: the month start is decided by
/// moon sighting and can differ from the table by a day or two per country.
class HijriDate {
  static const maxAdjust = 2;
  static const _key = 'prayer_hijri_adj';

  /// The package's Arabic names say "جمادى الثاني"; these are the usual
  /// forms (the sixth month is جمادى الآخرة).
  static const months = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
    'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
  ];

  static Future<int> loadAdjust() async =>
      (await SharedPreferences.getInstance()).getInt(_key) ?? 0;

  static Future<void> saveAdjust(int days) async =>
      (await SharedPreferences.getInstance())
          .setInt(_key, days.clamp(-maxAdjust, maxAdjust));

  /// e.g. "9 جمادى الآخرة 1448 هـ". Western digits like the prayer times:
  /// the app font draws Arabic-Indic digits very small.
  static String format(DateTime day, {int adjust = 0}) {
    final h =
        HijriCalendar.fromDate(DateTime(day.year, day.month, day.day + adjust));
    return '${h.hDay} ${months[h.hMonth - 1]} ${h.hYear} هـ';
  }
}
