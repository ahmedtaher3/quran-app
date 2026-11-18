import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled/features/prayer/adhan_scheduler.dart';

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

/// The five obligatory prayers, in order. Sunrise is shown for reference
/// but is never "the next prayer" and never gets an adhan.
const fivePrayers = [
  Prayer.fajr,
  Prayer.dhuhr,
  Prayer.asr,
  Prayer.maghrib,
  Prayer.isha,
];

/// Next prayer from [now]; after isha it rolls to tomorrow's fajr.
/// Between fajr and sunrise this is dhuhr, not sunrise.
(Prayer, DateTime) nextPrayer(PrayerSettings s, DateTime now) {
  final today = s.timesFor(now);
  for (final p in fivePrayers) {
    final at = today.timeForPrayer(p)!;
    if (at.isAfter(now)) return (p, at);
  }
  final tomorrow = s.timesFor(DateTime(now.year, now.month, now.day + 1));
  return (Prayer.fajr, tomorrow.fajr);
}

/// Latest prayer whose time has come; before fajr it is yesterday's isha.
(Prayer, DateTime) previousPrayer(PrayerSettings s, DateTime now) {
  final today = s.timesFor(now);
  for (final p in fivePrayers.reversed) {
    final at = today.timeForPrayer(p)!;
    if (!at.isAfter(now)) return (p, at);
  }
  final yesterday = s.timesFor(DateTime(now.year, now.month, now.day - 1));
  return (Prayer.isha, yesterday.isha);
}

/// Share of the time between the previous and the next prayer already
/// gone, 0..1.
double prayerProgress(PrayerSettings s, DateTime now) {
  final (_, from) = previousPrayer(s, now);
  final (_, to) = nextPrayer(s, now);
  final total = to.difference(from).inSeconds;
  if (total <= 0) return 0;
  return (now.difference(from).inSeconds / total).clamp(0.0, 1.0);
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

  /// Plans the adhan window for [s]; see [AdhanScheduler].
  static Future<void> scheduleAdhan(PrayerSettings s) =>
      AdhanScheduler.scheduleFor(s);
}
