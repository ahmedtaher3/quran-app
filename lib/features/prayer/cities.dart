import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

class City {
  final String name;
  final double lat, lng;
  const City(this.name, this.lat, this.lng);
}

/// For users who decline location, and to name a GPS position without a
/// geocoding service. City-centre coordinates; a few km off moves prayer
/// times by well under a minute.
const cities = <City>[
  City('القاهرة', 30.0444, 31.2357),
  City('الجيزة', 30.0131, 31.2089),
  City('الإسكندرية', 31.2001, 29.9187),
  City('بورسعيد', 31.2653, 32.3019),
  City('السويس', 29.9668, 32.5498),
  City('الإسماعيلية', 30.5965, 32.2715),
  City('المنصورة', 31.0409, 31.3785),
  City('طنطا', 30.7865, 31.0004),
  City('الزقازيق', 30.5877, 31.5020),
  City('دمياط', 31.4165, 31.8133),
  City('الفيوم', 29.3084, 30.8428),
  City('بني سويف', 29.0661, 31.0994),
  City('المنيا', 28.1099, 30.7503),
  City('أسيوط', 27.1809, 31.1837),
  City('سوهاج', 26.5591, 31.6957),
  City('قنا', 26.1551, 32.7160),
  City('الأقصر', 25.6872, 32.6396),
  City('أسوان', 24.0889, 32.8998),
  City('الغردقة', 27.2579, 33.8116),
  City('مرسى مطروح', 31.3543, 27.2373),
  City('العريش', 31.1316, 33.7984),
  City('شرم الشيخ', 27.9158, 34.3300),
  City('مكة المكرمة', 21.3891, 39.8579),
  City('المدينة المنورة', 24.5247, 39.5692),
  City('الرياض', 24.7136, 46.6753),
  City('جدة', 21.4858, 39.1925),
  City('الدمام', 26.4207, 50.0888),
  City('دبي', 25.2048, 55.2708),
  City('أبوظبي', 24.4539, 54.3773),
  City('الكويت', 29.3759, 47.9774),
  City('الدوحة', 25.2854, 51.5310),
  City('المنامة', 26.2285, 50.5860),
  City('مسقط', 23.5880, 58.3829),
  City('عمّان', 31.9454, 35.9284),
  City('القدس', 31.7683, 35.2137),
  City('بيروت', 33.8938, 35.5018),
  City('دمشق', 33.5138, 36.2765),
  City('بغداد', 33.3152, 44.3661),
  City('الخرطوم', 15.5007, 32.5599),
  City('طرابلس', 32.8872, 13.1913),
  City('تونس', 36.8065, 10.1815),
  City('الجزائر', 36.7538, 3.0588),
  City('الرباط', 34.0209, -6.8416),
  City('الدار البيضاء', 33.5731, -7.5898),
  City('إسطنبول', 41.0082, 28.9784),
  City('لندن', 51.5074, -0.1278),
  City('باريس', 48.8566, 2.3522),
  City('برلين', 52.5200, 13.4050),
  City('نيويورك', 40.7128, -74.0060),
  City('تورونتو', 43.6532, -79.3832),
  City('كوالالمبور', 3.1390, 101.6869),
  City('جاكرتا', -6.2088, 106.8456),
];

/// Great-circle distance in km.
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// The listed city closest to a point, if one is within [maxKm].
City? nearestCity(double lat, double lng, {double maxKm = 50}) {
  City? best;
  var bestKm = double.infinity;
  for (final c in cities) {
    final d = distanceKm(lat, lng, c.lat, c.lng);
    if (d < bestKm) {
      bestKm = d;
      best = c;
    }
  }
  return bestKm <= maxKm ? best : null;
}

/// Display name of the saved place; kept apart from PrayerSettings so the
/// existing settings keys stay untouched.
class PlaceStore {
  static const _key = 'prayer_place';

  static Future<String?> load() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  static Future<void> save(String? name) async {
    final p = await SharedPreferences.getInstance();
    if (name == null) {
      await p.remove(_key);
    } else {
      await p.setString(_key, name);
    }
  }
}
