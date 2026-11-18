import 'dart:math' as math;

import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:untitled/core/app_theme.dart';
import 'package:untitled/features/prayer/prayer_service.dart';
import 'package:untitled/features/prayer/qibla_sensor.dart';

const _okGreen = Color(0xFF2E7D32);
const _amber = Color(0xFFFFB300);

/// Signed turn from [heading] to [target], -180..180; positive = turn right.
double turnTo(double target, double heading) =>
    ((target - heading + 540) % 360) - 180;

class QiblaCompass extends StatelessWidget {
  final PrayerSettings settings;

  /// Degrees to add to the raw Android heading to get true north.
  final double declination;
  const QiblaCompass({super.key, required this.settings, required this.declination});

  @override
  Widget build(BuildContext context) {
    final qibla = Qibla(settings.coords).direction;
    return StreamBuilder<CompassEvent>(
      stream: FlutterCompass.events,
      builder: (context, snap) {
        final raw = snap.data?.heading;
        final heading =
            raw == null ? null : QiblaSensor.trueHeading(raw, declination);
        final turn = heading == null ? null : turnTo(qibla, heading);
        final aligned = turn != null && turn.abs() < 5;
        final dark = AppSettings.instance.isDark;
        final ok = dark ? const Color(0xFF6CC070) : _okGreen;

        return ListView(
          padding: EdgeInsets.fromLTRB(
              16, 4, 16, 24 + MediaQuery.paddingOf(context).bottom),
          children: [
            SizedBox(
              height: 48,
              child: Center(
                child: Text(
                  heading == null
                      ? 'البوصلة غير متاحة على هذا الجهاز'
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
                _Info(
                    label: 'اتجاهك',
                    value: heading == null ? '—' : '${heading.round()}°'),
                const SizedBox(width: 8),
                _Info(
                  label: 'الانحراف المغناطيسي',
                  // LTR isolate keeps "+5.1°" from flipping inside RTL text
                  value: declination == 0
                      ? '—'
                      : '\u2066${declination > 0 ? '+' : ''}${declination.toStringAsFixed(1)}°\u2069',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'القبلة محسوبة من الشمال الجغرافي. للدقة: أمسك الهاتف أفقيًا، '
              'وابتعد عن المعادن والمغناطيس، وحرّكه على شكل رقم 8 لمعايرة البوصلة.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.subtle, fontSize: 13, height: 1.6),
            ),
          ],
        );
      },
    );
  }
}

class _Info extends StatelessWidget {
  final String label, value;
  const _Info({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
            color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: AppColors.subtle)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.text)),
          ],
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  final double qibla;
  final bool aligned;
  final Color face, rim, tick, major, line;
  _DialPainter({
    required this.qibla,
    required this.aligned,
    required this.face,
    required this.rim,
    required this.tick,
    required this.major,
    required this.line,
  });

  Offset _at(Offset c, double deg, double r) {
    final a = (deg - 90) * math.pi / 180;
    return c + Offset(math.cos(a), math.sin(a)) * r;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 6;
    canvas.drawCircle(c, r, Paint()..color = face);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = aligned ? 6 : 4
          ..color = rim);

    for (var d = 0; d < 360; d += 10) {
      final isMajor = d % 90 == 0;
      final len = isMajor ? 14.0 : (d % 30 == 0 ? 9.0 : 5.0);
      canvas.drawLine(
          _at(c, d.toDouble(), r - 4),
          _at(c, d.toDouble(), r - 4 - len),
          Paint()
            ..strokeWidth = isMajor ? 2.4 : 1.2
            ..color = isMajor ? major : tick.withValues(alpha: 0.6));
    }

    const labels = {0: 'ش', 90: 'ق', 180: 'ج', 270: 'غ'};
    for (final e in labels.entries) {
      final tp = TextPainter(
        text: TextSpan(
            text: e.value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: e.key == 0 ? const Color(0xFFE53935) : tick)),
        textDirection: TextDirection.rtl,
      )..layout();
      tp.paint(canvas, _at(c, e.key.toDouble(), r - 36) - Offset(tp.width / 2, tp.height / 2));
    }

    // dashed line from the centre to the Kaaba
    final dash = Paint()
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = line;
    final end = r - 40;
    for (var d = 0.0; d < end; d += 9) {
      canvas.drawLine(_at(c, qibla, d), _at(c, qibla, math.min(d + 4, end)), dash);
    }
    canvas.drawCircle(c, 5, Paint()..color = line);

    // Kaaba: black block with the gold band, outlined so it shows on dark
    final k = _at(c, qibla, r - 26);
    canvas.save();
    canvas.translate(k.dx, k.dy);
    canvas.rotate(qibla * math.pi / 180);
    final box = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 26, height: 26), const Radius.circular(4));
    canvas.drawRRect(box, Paint()..color = const Color(0xFF1B1B1B));
    canvas.drawRRect(
        box,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _amber);
    canvas.drawRect(Rect.fromCenter(center: const Offset(0, -6), width: 26, height: 4),
        Paint()..color = _amber);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.qibla != qibla || old.aligned != aligned || old.face != face || old.rim != rim;
}
