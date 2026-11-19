part of 'qibla_compass.dart';

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

class _AccuracyRow extends StatelessWidget {
  final CompassAccuracy accuracy;
  final VoidCallback onCalibrate;
  const _AccuracyRow({required this.accuracy, required this.onCalibrate});

  @override
  Widget build(BuildContext context) {
    final dot = switch (accuracy) {
      CompassAccuracy.high => const Color(0xFF43A047),
      CompassAccuracy.medium => _amber,
      _ => const Color(0xFFE53935),
    };
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 4),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Container(
              width: 9, height: 9, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('دقة البوصلة: ${accuracy.label}',
                style: TextStyle(fontSize: 13, color: AppColors.subtle)),
          ),
          TextButton(onPressed: onCalibrate, child: const Text('معايرة')),
        ],
      ),
    );
  }
}

class _CalibrationBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _CalibrationBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
      decoration: BoxDecoration(
          color: AppColors.amberSoft, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Icon(Icons.explore_off_rounded, color: Color(0xFFB26A00)),
          const SizedBox(width: 10),
          Expanded(
            child: Text('دقة البوصلة منخفضة، والاتجاه قد يكون غير صحيح.',
                style: TextStyle(fontSize: 13, color: AppColors.text)),
          ),
          TextButton(onPressed: onTap, child: const Text('معايرة')),
        ],
      ),
    );
  }
}

/// How to recalibrate: an animated figure eight plus the usual advice.
Future<void> showCalibrationSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('معايرة البوصلة',
                style: TextStyle(
                    fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.text)),
            const SizedBox(height: 12),
            Container(
              height: 120,
              decoration: BoxDecoration(
                  color: AppColors.tealSoft, borderRadius: BorderRadius.circular(18)),
              child: const _FigureEight(),
            ),
            const SizedBox(height: 12),
            for (final line in const [
              'حرّك الهاتف في الهواء على شكل الرقم 8، من 3 إلى 4 مرات.',
              'ابتعد عن الأجهزة المعدنية والمغناطيس وجرابات المغناطيس.',
              'أمسك الهاتف أفقيًا موازيًا للأرض وأنت تقرأ الاتجاه.',
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 18, color: Theme.of(ctx).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(line,
                            style: TextStyle(fontSize: 14, color: AppColors.text))),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('تم')),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FigureEight extends StatefulWidget {
  const _FigureEight();

  @override
  State<_FigureEight> createState() => _FigureEightState();
}

class _FigureEightState extends State<_FigureEight>
    with SingleTickerProviderStateMixin {
  late final _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // respect "remove animations": show the path with the phone parked
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(painter: _EightPainter(_c.value, color)),
    );
  }
}

class _EightPainter extends CustomPainter {
  final double t;
  final Color color;
  _EightPainter(this.t, this.color);

  // lemniscate of Gerono: a horizontal figure eight
  Offset _at(double u, Size s) => Offset(
      s.width / 2 + s.width * 0.36 * math.sin(u),
      s.height / 2 + s.height * 0.32 * math.sin(u) * math.cos(u));

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (var i = 0; i <= 100; i++) {
      final p = _at(i / 100 * 2 * math.pi, size);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: 0.45));
    final p = _at(t * 2 * math.pi, size);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: p, width: 18, height: 30), const Radius.circular(5)),
        Paint()..color = color);
  }

  @override
  bool shouldRepaint(_EightPainter old) => old.t != t;
}

/// Devices without a magnetometer: the bearing in degrees and words, and
/// the sun as a reference while it is up.
class _NoCompass extends StatelessWidget {
  final PrayerSettings settings;
  final double qibla;
  final double bottomPadding;
  const _NoCompass(
      {required this.settings, required this.qibla, required this.bottomPadding});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final sun = SunPosition.at(DateTime.now(), settings.lat, settings.lng);
    final sunUp = sun.altitude > 3;
    final turn = turnTo(qibla, sun.azimuth);
    Widget card(IconData icon, String title, String body) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: primary, size: 20),
                const SizedBox(width: 8),
                Text(title,
                    style: TextStyle(fontWeight: FontWeight.bold, color: primary)),
              ]),
              const SizedBox(height: 6),
              Text(body, style: TextStyle(fontSize: 14, height: 1.6, color: AppColors.text)),
            ],
          ),
        );

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + bottomPadding),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppColors.tealSoft, borderRadius: BorderRadius.circular(16)),
          child: Text('هذا الجهاز لا يحتوي على حساس بوصلة، فهنا طرق بديلة لمعرفة الاتجاه.',
              style: TextStyle(fontSize: 14, color: AppColors.text)),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
          child: Row(
            children: [
              SizedBox(
                width: 84,
                height: 84,
                child: CustomPaint(painter: _BearingPainter(qibla, primary, AppColors.subtle)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${qibla.round()}°',
                        style: TextStyle(
                            fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.text)),
                    Text('نحو ${directionName(qibla)}، من الشمال الجغرافي',
                        style: TextStyle(fontSize: 13.5, color: AppColors.subtle)),
                  ],
                ),
              ),
            ],
          ),
        ),
        card(
          Icons.wb_sunny_rounded,
          'بالشمس',
          sunUp
              ? 'قف مواجهًا الشمس، ثم استدر ${turn > 0 ? 'يمينًا' : 'يسارًا'} '
                  'بمقدار ${turn.abs().round()}° تقريبًا لتواجه القبلة.'
              : 'الشمس غير ظاهرة الآن. استخدم الاتجاه بالدرجات أو محراب أقرب مسجد.',
        ),
        card(Icons.mosque_rounded, 'من حولك',
            'محراب أي مسجد قريب يشير إلى القبلة.'),
      ],
    );
  }
}

class _BearingPainter extends CustomPainter {
  final double bearing;
  final Color color, muted;
  _BearingPainter(this.bearing, this.color, this.muted);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = muted.withValues(alpha: 0.4));
    final n = TextPainter(
      text: const TextSpan(
          text: 'ش',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFE53935))),
      textDirection: TextDirection.rtl,
    )..layout();
    n.paint(canvas, Offset(c.dx - n.width / 2, 2));
    final a = (bearing - 90) * math.pi / 180;
    final tip = c + Offset(math.cos(a), math.sin(a)) * (r - 10);
    canvas.drawLine(
        c,
        tip,
        Paint()
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = color);
    canvas.drawCircle(c, 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BearingPainter old) => old.bearing != bearing;
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
