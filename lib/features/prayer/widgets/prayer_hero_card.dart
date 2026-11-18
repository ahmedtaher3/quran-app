import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:untitled/core/app_theme.dart';
import 'package:untitled/features/prayer/prayer_service.dart';

String _two(int n) => n.toString().padLeft(2, '0');

String formatCountdown(Duration d) {
  final s = d.isNegative ? Duration.zero : d;
  return '${_two(s.inHours)}:${_two(s.inMinutes % 60)}:${_two(s.inSeconds % 60)}';
}

/// Next prayer, live countdown and a ring for the time gone since the
/// previous prayer. Only this card rebuilds every second (rebuilding the
/// whole page each second used to swallow taps on the tab bar).
class PrayerHeroCard extends StatefulWidget {
  final PrayerSettings settings;
  final VoidCallback? onAlertTap;
  const PrayerHeroCard({super.key, required this.settings, this.onAlertTap});

  @override
  State<PrayerHeroCard> createState() => _PrayerHeroCardState();
}

class _PrayerHeroCardState extends State<PrayerHeroCard> {
  late final Timer _t =
      Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final now = DateTime.now();
    final (next, at) = nextPrayer(s, now);
    final (prev, from) = previousPrayer(s, now);
    final progress = prayerProgress(s, now);
    final left = at.difference(now);
    final tomorrow = at.day != now.day;
    final time = TimeOfDay.fromDateTime(at).format(context);
    final dark = AppSettings.instance.isDark;
    final noMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      container: true,
      label: 'الصلاة القادمة ${prayerNames[next]} الساعة $time، '
          'بعد ${left.inHours} ساعة و${left.inMinutes % 60} دقيقة',
      excludeSemantics: true, // the ticking digits would flood TalkBack
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: dark
                ? const [Color(0xFF0A332D), Color(0xFF00564C), Color(0xFF00695C)]
                : const [Color(0xFF004D40), Color(0xFF00796B), Color(0xFF00897B)],
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            const Positioned.fill(
                child: CustomPaint(painter: _StarPatternPainter())),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('الصلاة القادمة',
                                style: TextStyle(color: Colors.white70, fontSize: 13)),
                            Text(prayerNames[next]!,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    height: 1.3,
                                    fontWeight: FontWeight.bold)),
                            Text(tomorrow ? '$time · غدًا' : time,
                                style: const TextStyle(color: Colors.white, fontSize: 15)),
                            const SizedBox(height: 8),
                            _AlertChip(on: s.notify, onTap: widget.onAlertTap),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: progress),
                        duration: noMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 800),
                        builder: (context, p, _) => _Ring(
                          progress: p,
                          countdown: formatCountdown(left),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'بعد ${prayerNames[prev]} '
                          '${TimeOfDay.fromDateTime(from).format(context)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text('مضى ${(progress * 100).round()}% من الوقت',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertChip extends StatelessWidget {
  final bool on;
  final VoidCallback? onTap;
  const _AlertChip({required this.on, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(on ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
                  size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Flexible(
                child: Text(on ? 'تنبيه الأذان مفعّل' : 'تنبيه الأذان متوقف',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  final double progress;
  final String countdown;
  const _Ring({required this.progress, required this.countdown});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      height: 116,
      child: CustomPaint(
        painter: _RingPainter(progress),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(countdown,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto',
                        fontFeatures: [FontFeature.tabularFigures()])),
              ),
              const Text('متبقٍ', style: TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 6;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = Colors.white.withValues(alpha: 0.16);
    canvas.drawCircle(c, r, track);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFFC233);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0), false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

/// Faint eight-point star grid, the app's Islamic geometric accent.
class _StarPatternPainter extends CustomPainter {
  const _StarPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.08);
    const step = 34.0, half = 9.0;
    for (var y = 0.0; y < size.height + step; y += step) {
      for (var x = 0.0; x < size.width + step; x += step) {
        final c = Offset(x, y);
        canvas.drawRect(Rect.fromCenter(center: c, width: half * 2, height: half * 2), p);
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(math.pi / 4);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: half * 2, height: half * 2), p);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_StarPatternPainter old) => false;
}
