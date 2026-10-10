import 'dart:async';
import 'dart:math' as math;

import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:untitled/core/notifications.dart';
import 'package:untitled/features/prayer/prayer_service.dart';

const _teal = Color(0xFF00695C);

class PrayerView extends StatefulWidget {
  const PrayerView({super.key});

  @override
  State<PrayerView> createState() => _PrayerViewState();
}

class _PrayerViewState extends State<PrayerView> {
  PrayerSettings? _s;
  String? _error;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final s = await PrayerStore.load();
    if (s != null) {
      setState(() => _s = s);
      PrayerStore.scheduleAdhan(s); // keep the next 2 days planned
    } else {
      await _locate();
    }
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    final (pos, err) = await PrayerStore.locate();
    if (!mounted) return;
    if (pos == null) {
      setState(() {
        _error = err;
        _locating = false;
      });
      return;
    }
    final old = _s;
    final s = PrayerSettings(
      pos.latitude,
      pos.longitude,
      old?.method ?? CalculationMethod.egyptian,
      old?.madhab ?? Madhab.shafi,
      old?.notify ?? false,
    );
    await PrayerStore.save(s);
    setState(() {
      _s = s;
      _locating = false;
    });
  }

  Future<void> _update(PrayerSettings s) async {
    if (s.notify && !(_s?.notify ?? false)) {
      await Notifications.requestPermission();
    }
    await PrayerStore.save(s);
    setState(() => _s = s);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FBF9),
        appBar: AppBar(
          title: const Text("مواقيت الصلاة",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: _teal,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              tooltip: "تحديث الموقع",
              icon: _locating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.my_location_rounded),
              onPressed: _locating ? null : _locate,
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Color(0xFFFFB300),
            tabs: [
              Tab(icon: Icon(Icons.access_time_rounded), text: "المواقيت"),
              Tab(icon: Icon(Icons.explore_rounded), text: "القبلة"),
            ],
          ),
        ),
        body: _s == null
            ? _empty()
            : TabBarView(children: [_times(_s!), _QiblaTab(s: _s!)]),
      ),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on_rounded,
                  size: 64, color: Colors.teal.shade200),
              const SizedBox(height: 12),
              Text(
                _error ?? "جاري تحديد موقعك…",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, height: 1.8),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _locate,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _teal, foregroundColor: Colors.white),
                  child: const Text("حاول مرة أخرى"),
                ),
              ],
            ],
          ),
        ),
      );

  Widget _times(PrayerSettings s) {
    final now = DateTime.now();
    final t = s.timesFor(now);
    final (next, at) = nextPrayer(s, now);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Countdown(s: s),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              for (final p in [
                Prayer.fajr,
                Prayer.sunrise,
                Prayer.dhuhr,
                Prayer.asr,
                Prayer.maghrib,
                Prayer.isha
              ])
                ListTile(
                  leading: Icon(
                    p == Prayer.sunrise
                        ? Icons.wb_twilight_rounded
                        : Icons.mosque_rounded,
                    color: p == next && at.day == now.day
                        ? const Color(0xFFFFA000)
                        : Colors.teal.shade300,
                  ),
                  title: Text(prayerNames[p]!,
                      style: TextStyle(
                          fontWeight: p == next && at.day == now.day
                              ? FontWeight.bold
                              : FontWeight.normal)),
                  trailing: Text(
                      TimeOfDay.fromDateTime(t.timeForPrayer(p)!)
                          .format(context),
                      style: const TextStyle(fontSize: 16)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          value: s.notify,
          onChanged: (v) => _update(PrayerSettings(
              s.lat, s.lng, s.method, s.madhab, v)),
          title: const Text("تنبيه عند دخول وقت الصلاة"),
          secondary: const Icon(Icons.notifications_active_rounded,
              color: _teal),
        ),
        ListTile(
          leading: const Icon(Icons.calculate_rounded, color: _teal),
          title: const Text("طريقة الحساب"),
          subtitle: Text(methodNames[s.method] ?? s.method.name),
          onTap: () async {
            final m = await showModalBottomSheet<CalculationMethod>(
              context: context,
              builder: (_) => SafeArea(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final e in methodNames.entries)
                      RadioListTile<CalculationMethod>(
                        value: e.key,
                        groupValue: s.method,
                        title: Text(e.value),
                        onChanged: (v) => Navigator.pop(context, v),
                      ),
                  ],
                ),
              ),
            );
            if (m != null) {
              _update(PrayerSettings(s.lat, s.lng, m, s.madhab, s.notify));
            }
          },
        ),
        SwitchListTile(
          value: s.madhab == Madhab.hanafi,
          onChanged: (v) => _update(PrayerSettings(s.lat, s.lng, s.method,
              v ? Madhab.hanafi : Madhab.shafi, s.notify)),
          title: const Text("العصر على المذهب الحنفي"),
          secondary: const Icon(Icons.wb_sunny_outlined, color: _teal),
        ),
      ],
    );
  }
}

class _QiblaTab extends StatelessWidget {
  final PrayerSettings s;
  const _QiblaTab({required this.s});

  @override
  Widget build(BuildContext context) {
    final qibla = Qibla(s.coords).direction;
    return StreamBuilder<CompassEvent>(
      stream: FlutterCompass.events,
      builder: (context, snap) {
        final heading = snap.data?.heading;
        final hasCompass = heading != null;
        // dial rotates so north on the dial matches real north; the kaaba
        // marker sits at the qibla bearing on that dial
        final dial = hasCompass ? -heading * math.pi / 180 : 0.0;
        final diff = hasCompass ? ((qibla - heading + 540) % 360) - 180 : null;
        final aligned = diff != null && diff.abs() < 5;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              hasCompass
                  ? aligned
                      ? "أنت في اتجاه القبلة ✓"
                      : "أدر الهاتف حتى يشير السهم إلى الكعبة"
                  : "البوصلة غير متاحة على هذا الجهاز، اتجاه القبلة ${qibla.toStringAsFixed(0)}° من الشمال",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 17,
                  height: 1.8,
                  color: aligned ? Colors.green.shade700 : Colors.black87,
                  fontWeight: aligned ? FontWeight.bold : FontWeight.normal),
            ),
            const SizedBox(height: 24),
            AspectRatio(
              aspectRatio: 1,
              child: Transform.rotate(
                angle: dial,
                child: CustomPaint(
                  painter: _DialPainter(qibla, aligned),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "اتجاه القبلة: ${qibla.toStringAsFixed(1)}° من الشمال الجغرافي",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            if (hasCompass)
              Text(
                "اتجاه الهاتف: ${heading.toStringAsFixed(0)}°",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500),
              ),
            const SizedBox(height: 12),
            Text(
              "للدقة: ابعد الهاتف عن المعادن والمغناطيس، وحرّكه على شكل رقم 8 لمعايرة البوصلة",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        );
      },
    );
  }
}

class _DialPainter extends CustomPainter {
  final double qibla;
  final bool aligned;
  _DialPainter(this.qibla, this.aligned);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 8;
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = aligned ? Colors.green : Colors.teal.shade100);

    // ticks every 30°, cardinal letters
    final tick = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 2;
    for (var d = 0; d < 360; d += 30) {
      final a = (d - 90) * math.pi / 180;
      final o = c + Offset(math.cos(a), math.sin(a)) * r;
      final i = c + Offset(math.cos(a), math.sin(a)) * (r - 12);
      canvas.drawLine(i, o, tick);
    }
    const labels = {0: 'ش', 90: 'ق', 180: 'ج', 270: 'غ'};
    for (final e in labels.entries) {
      final a = (e.key - 90) * math.pi / 180;
      final p = c + Offset(math.cos(a), math.sin(a)) * (r - 30);
      final tp = TextPainter(
        text: TextSpan(
            text: e.value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: e.key == 0 ? Colors.red.shade400 : Colors.grey.shade600)),
        textDirection: TextDirection.rtl,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }

    // needle toward qibla
    final a = (qibla - 90) * math.pi / 180;
    final dir = Offset(math.cos(a), math.sin(a));
    final tip = c + dir * (r - 50);
    final needle = Paint()
      ..color = aligned ? Colors.green.shade600 : const Color(0xFF00695C)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c - dir * 30, tip, needle);
    canvas.drawCircle(c, 8, Paint()..color = const Color(0xFF00695C));

    // kaaba marker
    final k = c + dir * (r - 28);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: k, width: 26, height: 26),
            const Radius.circular(4)),
        Paint()..color = Colors.black87);
    canvas.drawRect(Rect.fromCenter(center: k - const Offset(0, 6), width: 26, height: 4),
        Paint()..color = const Color(0xFFFFB300));
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.qibla != qibla || old.aligned != aligned;
}

/// Only this card ticks every second; rebuilding the whole page each
/// second was swallowing taps on the tab bar.
class _Countdown extends StatefulWidget {
  final PrayerSettings s;
  const _Countdown({required this.s});

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  late final Timer _t =
      Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final (next, at) = nextPrayer(widget.s, now);
    final left = at.difference(now);
    String two(int n) => n.toString().padLeft(2, '0');
    final countdown =
        "${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}";
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF004D40), Color(0xFF00897B)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Text("الصلاة القادمة: ${prayerNames[next]}",
              style: const TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(countdown,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto',
                    fontFeatures: [FontFeature.tabularFigures()])),
          ),
          Text(TimeOfDay.fromDateTime(at).format(context),
              style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
