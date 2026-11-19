import 'dart:math' as math;

/// Where the sun is in the sky, for finding the qibla without a compass:
/// face the sun, then turn by the difference. Low-precision solar formulas
/// (about a degree), plenty for this.
class SunPosition {
  /// Degrees clockwise from true north.
  final double azimuth;

  /// Degrees above the horizon; negative = below.
  final double altitude;
  const SunPosition(this.azimuth, this.altitude);

  static double _rad(double d) => d * math.pi / 180;
  static double _deg(double r) => r * 180 / math.pi;
  static double _fix(double a, double b) => ((a % b) + b) % b;

  static SunPosition at(DateTime time, double lat, double lng) {
    final utc = time.toUtc();
    // days since J2000.0
    final d = utc.difference(DateTime.utc(2000, 1, 1, 12)).inMilliseconds /
        Duration.millisecondsPerDay;
    final g = _fix(357.529 + 0.98560028 * d, 360);
    final q = _fix(280.459 + 0.98564736 * d, 360);
    final l = _fix(q + 1.915 * math.sin(_rad(g)) + 0.020 * math.sin(_rad(2 * g)), 360);
    final e = 23.439 - 0.00000036 * d;
    final ra = _fix(_deg(math.atan2(math.cos(_rad(e)) * math.sin(_rad(l)), math.cos(_rad(l)))) / 15, 24);
    final decl = _deg(math.asin(math.sin(_rad(e)) * math.sin(_rad(l))));
    final eqt = q / 15 - ra; // hours

    final utcHours = utc.hour + utc.minute / 60 + utc.second / 3600;
    final solarTime = utcHours + lng / 15 + eqt;
    final h = _rad((solarTime - 12) * 15); // hour angle
    final la = _rad(lat), de = _rad(decl);

    final alt = _deg(math.asin(
        math.sin(la) * math.sin(de) + math.cos(la) * math.cos(de) * math.cos(h)));
    final az = _fix(
        _deg(math.atan2(math.sin(h),
                math.cos(h) * math.sin(la) - math.tan(de) * math.cos(la))) +
            180,
        360);
    return SunPosition(az, alt);
  }
}
