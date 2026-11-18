import 'dart:async';

import 'package:adhan/adhan.dart';
import 'package:flutter/widgets.dart';
import 'package:untitled/features/prayer/prayer_service.dart';

/// Earliest moment the prayer list must change after [now]: the next of the
/// six times today (sunrise too, it changes which rows are past) or midnight.
DateTime nextBoundary(PrayerSettings s, DateTime now) {
  final t = s.timesFor(now);
  for (final p in const [
    Prayer.fajr,
    Prayer.sunrise,
    Prayer.dhuhr,
    Prayer.asr,
    Prayer.maghrib,
    Prayer.isha,
  ]) {
    final at = t.timeForPrayer(p)!;
    if (at.isAfter(now)) return at;
  }
  return DateTime(now.year, now.month, now.day + 1);
}

/// Notifies at each prayer boundary, at midnight and when the app returns
/// to the foreground, so the list updates without rebuilding every second.
class PrayerClock extends ChangeNotifier with WidgetsBindingObserver {
  PrayerClock(this._settings);

  PrayerSettings _settings;
  Timer? _timer;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _arm();
  }

  set settings(PrayerSettings s) {
    _settings = s;
    _arm();
    notifyListeners();
  }

  void _arm() {
    _timer?.cancel();
    final now = DateTime.now();
    final wait = nextBoundary(_settings, now).difference(now) +
        const Duration(milliseconds: 500);
    _timer = Timer(wait, () {
      notifyListeners();
      _arm();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _arm(); // timers can drift while the app sleeps
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
