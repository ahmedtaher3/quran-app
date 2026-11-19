import 'package:adhan/adhan.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:untitled/core/notifications.dart';
import 'package:untitled/features/prayer/adhan_prefs.dart';
import 'package:untitled/features/prayer/adhan_scheduler.dart';
import 'package:untitled/features/prayer/cities.dart';
import 'package:untitled/features/prayer/hijri_date.dart';
import 'package:untitled/features/prayer/prayer_background.dart';
import 'package:untitled/features/prayer/prayer_clock.dart';
import 'package:untitled/features/prayer/prayer_service.dart';
import 'package:untitled/features/prayer/qibla_sensor.dart';
import 'package:untitled/features/prayer/widget_sync.dart';

/// More than [km] from the saved place: worth offering a location update
/// (travel), without ever changing it silently.
bool isFarFrom(PrayerSettings s, double lat, double lng, {double km = 25}) =>
    distanceKm(s.lat, s.lng, lat, lng) > km;

/// State of the prayer screen and its settings screen, which both listen
/// to it. Same plain ChangeNotifier style as AppSettings.
class PrayerController extends ChangeNotifier with WidgetsBindingObserver {
  PrayerSettings? settings;
  String? place;
  int hijriAdjust = 0;
  bool loaded = false;
  bool locating = false;
  bool moved = false;
  bool exactOk = true;
  String? error;
  double declination = 0;
  Map<Prayer, PrayerAlert> alerts = const {};
  PrayerClock? clock;
  bool _disposed = false;

  PrayerAlert alertFor(Prayer p) => alerts[p] ?? const PrayerAlert();

  Future<void> setAlert(Prayer p, PrayerAlert a) async {
    alerts = {...alerts, p: a};
    _notify();
    await AdhanPrefs.save(p, a);
    final s = settings;
    if (s != null) await AdhanScheduler.scheduleFor(s);
  }

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    final s = await PrayerStore.load();
    place = await PlaceStore.load();
    hijriAdjust = await HijriDate.loadAdjust();
    alerts = await AdhanPrefs.load();
    loaded = true;
    if (s != null) {
      _apply(s);
      refreshExact();
      _checkMoved(s);
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _apply(PrayerSettings s) {
    if (_disposed) return; // screen closed while loading or locating
    final newPlace =
        settings == null || settings!.lat != s.lat || settings!.lng != s.lng;
    settings = s;
    if (clock == null) {
      clock = PrayerClock(s)..start();
    } else {
      clock!.settings = s;
    }
    if (newPlace) {
      QiblaSensor.declination(s.lat, s.lng).then((d) {
        declination = d;
        _notify();
      });
    }
    _notify();
  }

  /// Back from the "Alarms & reminders" page, or after a settings change.
  Future<void> refreshExact() async {
    final ok = await Notifications.canScheduleExact();
    if (ok != exactOk) {
      exactOk = ok;
      _notify();
    }
    await AdhanScheduler.ensureFresh();
  }

  Future<void> locate() async {
    locating = true;
    error = null;
    _notify();
    final (pos, err) = await PrayerStore.locate();
    locating = false;
    if (pos == null) {
      error = err;
      _notify();
      return;
    }
    await _saveLocation(pos.latitude, pos.longitude,
        nearestCity(pos.latitude, pos.longitude)?.name);
  }

  Future<void> useCity(City c) => _saveLocation(c.lat, c.lng, c.name);

  Future<void> _saveLocation(double lat, double lng, String? name) async {
    final old = settings;
    final s = PrayerSettings(
      lat,
      lng,
      old?.method ?? CalculationMethod.egyptian,
      old?.madhab ?? Madhab.shafi,
      old?.notify ?? false,
    );
    await PrayerStore.save(s);
    await PlaceStore.save(name);
    place = name;
    moved = false;
    error = null;
    _apply(s);
    WidgetSync.update(); // place name changed after the replan
    if (old == null) PrayerBackground.ensurePeriodic();
  }

  Future<void> update(PrayerSettings s) async {
    if (s.notify && !(settings?.notify ?? false)) {
      await Notifications.requestPermission();
    }
    await PrayerStore.save(s);
    _apply(s);
    refreshExact();
  }

  Future<void> setHijriAdjust(int days) async {
    hijriAdjust = days.clamp(-HijriDate.maxAdjust, HijriDate.maxAdjust);
    _notify();
    await HijriDate.saveAdjust(hijriAdjust);
    await WidgetSync.update();
  }

  void dismissMoved() {
    moved = false;
    _notify();
  }

  /// Uses the last fix the system already has; never asks for permission.
  Future<void> _checkMoved(PrayerSettings s) async {
    try {
      final p = await Geolocator.checkPermission();
      if (p != LocationPermission.whileInUse && p != LocationPermission.always) {
        return;
      }
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && isFarFrom(s, last.latitude, last.longitude)) {
        moved = true;
        _notify();
      }
    } catch (_) {
      // no last fix or service off: nothing to suggest
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && settings != null) refreshExact();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    clock?.dispose();
    super.dispose();
  }
}
