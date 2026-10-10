import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled/core/notifications.dart';

const prayerNames = {
  Prayer.fajr: "الفجر",
  Prayer.sunrise: "الشروق",
  Prayer.dhuhr: "الظهر",
  Prayer.asr: "العصر",
  Prayer.maghrib: "المغرب",
  Prayer.isha: "العشاء",
};

const methodNames = {
  CalculationMethod.egyptian: "الهيئة المصرية العامة للمساحة",
  CalculationMethod.umm_al_qura: "أم القرى (مكة)",
  CalculationMethod.muslim_world_league: "رابطة العالم الإسلامي",
  CalculationMethod.karachi: "جامعة العلوم الإسلامية بكراتشي",
  CalculationMethod.dubai: "دبي",
  CalculationMethod.kuwait: "الكويت",
  CalculationMethod.qatar: "قطر",
  CalculationMethod.turkey: "تركيا",
  CalculationMethod.north_america: "أمريكا الشمالية",
};

class PrayerSettings {
  final double lat, lng;
  final CalculationMethod method;
  final Madhab madhab;
  final bool notify;
  const PrayerSettings(this.lat, this.lng, this.method, this.madhab, this.notify);

  Coordinates get coords => Coordinates(lat, lng);

  CalculationParameters get params =>
      method.getParameters()..madhab = madhab;

  PrayerTimes timesFor(DateTime day) =>
      PrayerTimes(coords, DateComponents.from(day), params);
}

/// Next prayer from [now]; after isha it rolls to tomorrow's fajr.
(Prayer, DateTime) nextPrayer(PrayerSettings s, DateTime now) {
  final today = s.timesFor(now);
  final p = today.nextPrayerByDateTime(now);
  if (p != Prayer.none) return (p, today.timeForPrayer(p)!);
  final tomorrow = s.timesFor(DateTime(now.year, now.month, now.day + 1));
  return (Prayer.fajr, tomorrow.fajr);
}

class PrayerStore {
  static const _k = 'prayer_';

  static Future<PrayerSettings?> load() async {
    final p = await SharedPreferences.getInstance();
    final lat = p.getDouble('${_k}lat'), lng = p.getDouble('${_k}lng');
    if (lat == null || lng == null) return null;
    return PrayerSettings(
      lat,
      lng,
      CalculationMethod.values.byName(p.getString('${_k}method') ?? 'egyptian'),
      Madhab.values.byName(p.getString('${_k}madhab') ?? 'shafi'),
      p.getBool('${_k}notify') ?? false,
    );
  }

  static Future<void> save(PrayerSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('${_k}lat', s.lat);
    await p.setDouble('${_k}lng', s.lng);
    await p.setString('${_k}method', s.method.name);
    await p.setString('${_k}madhab', s.madhab.name);
    await p.setBool('${_k}notify', s.notify);
    await scheduleAdhan(s);
  }

  /// Returns null with a user-facing reason if location isn't available.
  static Future<(Position?, String?)> locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return (null, "خدمة الموقع مغلقة، فعّلها من إعدادات الجهاز");
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return (null, "نحتاج إذن الموقع لحساب مواقيت الصلاة واتجاه القبلة");
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    );
    return (pos, null);
  }

  static const _baseId = 200; // 200..211: today + tomorrow, 6 slots each

  /// Plans adhan notifications for today and tomorrow (5 prayers, no sunrise).
  static Future<void> scheduleAdhan(PrayerSettings s) async {
    for (var i = 0; i < 12; i++) {
      await Notifications.cancel(_baseId + i);
    }
    if (!s.notify) return;
    final now = DateTime.now();
    for (var d = 0; d < 2; d++) {
      final day = DateTime(now.year, now.month, now.day + d);
      final t = s.timesFor(day);
      final list = [
        (Prayer.fajr, t.fajr),
        (Prayer.dhuhr, t.dhuhr),
        (Prayer.asr, t.asr),
        (Prayer.maghrib, t.maghrib),
        (Prayer.isha, t.isha),
      ];
      for (var i = 0; i < list.length; i++) {
        final (p, at) = list[i];
        await Notifications.scheduleAt(
          id: _baseId + d * 6 + i,
          at: at,
          title: "حان الآن موعد صلاة ${prayerNames[p]}",
          body: "حيّ على الصلاة، حيّ على الفلاح",
        );
      }
    }
  }
}
