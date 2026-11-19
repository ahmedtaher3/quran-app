import 'dart:convert';
import 'dart:io';

import 'package:adhan/adhan.dart';
import 'package:home_widget/home_widget.dart';
import 'package:untitled/features/prayer/cities.dart';
import 'package:untitled/features/prayer/hijri_date.dart';
import 'package:untitled/features/prayer/prayer_service.dart';

/// Feeds the Android home-screen widget (PrayerWidgetProvider.kt).
///
/// The widget never runs Dart: it reads a week of absolute prayer times
/// written here, picks the next one itself, counts down with a
/// Chronometer and refreshes at prayer boundaries with a non-waking alarm.
/// Written on every replan (app start, settings, background job), so the
/// week always rolls forward while the adhan window does.
class WidgetSync {
  static const payloadKey = 'prayer_widget';
  static const androidName = 'PrayerWidgetProvider';
  static const launchUri = 'tarikquran://prayer';

  static const _six = [
    Prayer.fajr,
    Prayer.sunrise,
    Prayer.dhuhr,
    Prayer.asr,
    Prayer.maghrib,
    Prayer.isha,
  ];

  /// Index of sunrise in `names`/`times`; the widget never counts down to it.
  static const sunriseIndex = 1;

  static Map<String, Object?> buildPayload(
    PrayerSettings s,
    DateTime now, {
    String? place,
    int hijriAdjust = 0,
    int days = 7,
  }) {
    return {
      'v': 1,
      'place': place ?? 'موقعك الحالي',
      'names': [for (final p in _six) prayerNames[p]],
      'days': [
        for (var d = 0; d < days; d++)
          () {
            final day = DateTime(now.year, now.month, now.day + d);
            final t = s.timesFor(day);
            return {
              'hijri': HijriDate.format(day, adjust: hijriAdjust),
              'times': [
                for (final p in _six) t.timeForPrayer(p)!.millisecondsSinceEpoch
              ],
            };
          }(),
      ],
    };
  }

  /// Writes the payload and redraws the widget. Never throws: a widget
  /// problem must not break adhan scheduling.
  static Future<void> update() async {
    if (!Platform.isAndroid) return;
    try {
      final s = await PrayerStore.load();
      if (s == null) return;
      final payload = buildPayload(
        s,
        DateTime.now(),
        place: await PlaceStore.load(),
        hijriAdjust: await HijriDate.loadAdjust(),
      );
      await HomeWidget.saveWidgetData<String>(payloadKey, jsonEncode(payload));
      await HomeWidget.updateWidget(androidName: androidName);
    } catch (_) {
      // no widget plugin in this engine, or no widget placed: nothing to do
    }
  }

  static bool isPrayerUri(Uri? uri) => uri?.host == 'prayer';

  /// Whether this launcher can add the widget from inside the app
  /// (Android 8+ with a supporting launcher).
  static Future<bool> canPin() async {
    if (!Platform.isAndroid) return false;
    try {
      return await HomeWidget.isRequestPinWidgetSupported() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Asks the launcher to place the widget; the system shows its own
  /// confirmation.
  static Future<void> pin() async {
    await update(); // so it shows real times the moment it lands
    await HomeWidget.requestPinWidget(
        qualifiedAndroidName: 'com.tarik.al.quran.PrayerWidgetProvider');
  }
}
