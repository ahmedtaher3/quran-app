import 'dart:io';

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
