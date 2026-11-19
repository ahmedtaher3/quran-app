import 'dart:async';
import 'dart:math' as math;

import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:untitled/core/app_theme.dart';
import 'package:untitled/features/prayer/prayer_service.dart';
import 'package:untitled/features/prayer/qibla_sensor.dart';
import 'package:untitled/features/prayer/sun_position.dart';
import 'package:untitled/features/prayer/widgets/time_format.dart';

part 'qibla_parts.dart';

const _amber = Color(0xFFFFB300);

/// Signed turn from [heading] to [target], -180..180; positive = turn right.
double turnTo(double target, double heading) =>
    ((target - heading + 540) % 360) - 180;

const _directions = [
  'الشمال', 'الشمال الشرقي', 'الشرق', 'الجنوب الشرقي',
  'الجنوب', 'الجنوب الغربي', 'الغرب', 'الشمال الغربي',
];
String directionName(double bearing) => _directions[((bearing % 360) / 45).round() % 8];

class QiblaCompass extends StatefulWidget {
  final PrayerSettings settings;

  /// Degrees to add to the raw Android heading to get true north.
  final double declination;
  const QiblaCompass({super.key, required this.settings, required this.declination});

  @override
  State<QiblaCompass> createState() => _QiblaCompassState();
}

class _QiblaCompassState extends State<QiblaCompass> {
  final _smoother = HeadingSmoother();
  final _latch = AlignmentLatch();
  StreamSubscription<CompassEvent>? _sub;
  double? _heading;
  CompassAccuracy _accuracy = CompassAccuracy.unknown;
  bool _noSensor = false;

  @override
  void initState() {
    super.initState();
    final events = FlutterCompass.events;
    if (events == null) {
      _noSensor = true;
      return;
    }
    _sub = events.listen(_onEvent, onError: (_) {
      if (mounted) setState(() => _noSensor = true);
    });
  }

  void _onEvent(CompassEvent e) {
    final raw = e.heading;
    if (raw == null) {
      if (mounted && _heading == null) setState(() => _noSensor = true);
      return;
    }
    final h = _smoother.add(QiblaSensor.trueHeading(raw, widget.declination));
    final qibla = Qibla(widget.settings.coords).direction;
    if (_latch.update(turnTo(qibla, h))) HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() {
      _noSensor = false;
      _heading = h;
      _accuracy = CompassAccuracy.from(e.accuracy);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qibla = Qibla(widget.settings.coords).direction;
    final bottom = MediaQuery.paddingOf(context).bottom;
    if (_noSensor) {
      return _NoCompass(settings: widget.settings, qibla: qibla, bottomPadding: bottom);
    }
    final heading = _heading;
    final turn = heading == null ? null : turnTo(qibla, heading);
    final aligned = _latch.aligned && heading != null;
    final ok = AppSettings.instance.isDark ? const Color(0xFF6CC070) : const Color(0xFF2E7D32);

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + bottom),
      children: [
        if (heading != null && _accuracy.needsCalibration)
          _CalibrationBanner(onTap: () => showCalibrationSheet(context)),
        SizedBox(
          height: 48,
          child: Center(
            child: Text(
              heading == null
                  ? 'جارٍ قراءة البوصلة…'
                  : aligned
                      ? 'أنت في اتجاه القبلة ✓'
                      : 'استدر ${turn! > 0 ? 'يمينًا' : 'يسارًا'} ${turn.abs().round()}°',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: aligned ? ok : AppColors.text),
            ),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Transform.rotate(
                      // the dial turns so its north matches true north;
                      // the Kaaba sits at the qibla bearing on it
                      angle: heading == null ? 0 : -heading * math.pi / 180,
                      child: CustomPaint(
                        painter: _DialPainter(
                          qibla: qibla,
                          aligned: aligned,
                          face: AppColors.surface,
                          rim: aligned ? ok : AppColors.tealSoft,
                          tick: AppColors.subtle,
                          major: AppColors.text,
                          line: aligned ? ok : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  // fixed marker: where the top of the phone points
                  const Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.arrow_drop_down_rounded, color: _amber, size: 40),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _Info(label: 'القبلة', value: '${qibla.toStringAsFixed(1)}°'),
            const SizedBox(width: 8),
            _Info(label: 'اتجاهك', value: heading == null ? '—' : '${heading.round()}°'),
            const SizedBox(width: 8),
            _Info(
              label: 'الانحراف المغناطيسي',
              value: widget.declination == 0
                  ? '—'
                  : ltr('${widget.declination > 0 ? '+' : ''}'
                      '${widget.declination.toStringAsFixed(1)}°'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _AccuracyRow(
            accuracy: _accuracy, onCalibrate: () => showCalibrationSheet(context)),
        const SizedBox(height: 10),
        Text(
          'القبلة محسوبة من الشمال الجغرافي. أمسك الهاتف أفقيًا وابتعد عن المعادن والمغناطيس.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.subtle, fontSize: 13, height: 1.6),
        ),
      ],
    );
  }
}
