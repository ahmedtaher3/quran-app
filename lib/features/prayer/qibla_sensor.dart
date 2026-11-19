import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';

/// Compass helpers for the qibla tab.
///
/// flutter_compass on Android reads TYPE_ROTATION_VECTOR, whose azimuth is
/// relative to *magnetic* north, while the qibla bearing is relative to
/// *true* north. On iOS the plugin already returns trueHeading, so the
/// correction is Android-only (applying it twice would be wrong).
class QiblaSensor {
  static const _channel = MethodChannel('tarik/prayer');

  /// Magnetic declination in degrees, east positive, from Android's
  /// GeomagneticField (World Magnetic Model). 0 where not needed/available.
  static Future<double> declination(double lat, double lng) async {
    if (!Platform.isAndroid) return 0;
    try {
      final d = await _channel
          .invokeMethod<double>('declination', {'lat': lat, 'lng': lng});
      return d ?? 0;
    } on PlatformException {
      return 0;
    } on MissingPluginException {
      return 0;
    }
  }

  /// Heading from true north, 0..360.
  static double trueHeading(double magnetic, double declination) =>
      (magnetic + declination) % 360;
}

/// Low-pass filter for compass headings. Averages unit vectors, not raw
/// degrees, so 359° and 1° average to 0° instead of spinning to 180°.
class HeadingSmoother {
  HeadingSmoother({this.alpha = 0.15});

  /// Weight of each new reading; lower = steadier but slower.
  final double alpha;
  double? _x, _y;

  double add(double degrees) {
    final r = degrees * math.pi / 180;
    final x = math.cos(r), y = math.sin(r);
    if (_x == null) {
      _x = x;
      _y = y;
    } else {
      _x = _x! + alpha * (x - _x!);
      _y = _y! + alpha * (y - _y!);
    }
    return (math.atan2(_y!, _x!) * 180 / math.pi) % 360;
  }
}

/// "Facing the qibla" with hysteresis: on under [enter] degrees, off only
/// past [exit], so the state (and the haptic tick) doesn't flicker at the
/// edge.
class AlignmentLatch {
  static const enter = 3.0, exit = 6.0;
  bool aligned = false;

  /// Returns true only on the transition into alignment.
  bool update(double turnDegrees) {
    final was = aligned;
    aligned = aligned ? turnDegrees.abs() < exit : turnDegrees.abs() < enter;
    return aligned && !was;
  }
}

/// Sensor accuracy as flutter_compass reports it on Android: 15/30/45
/// degrees for high/medium/low, null when unreliable or unknown.
enum CompassAccuracy {
  high('عالية'),
  medium('متوسطة'),
  low('منخفضة'),
  unknown('غير معروفة');

  final String label;
  const CompassAccuracy(this.label);

  static CompassAccuracy from(double? degrees) => degrees == null
      ? CompassAccuracy.unknown
      : degrees <= 15
          ? CompassAccuracy.high
          : degrees <= 30
              ? CompassAccuracy.medium
              : CompassAccuracy.low;

  bool get needsCalibration => this == low || this == unknown;
}
