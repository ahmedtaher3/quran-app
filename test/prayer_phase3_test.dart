import 'package:adhan/adhan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:untitled/features/prayer/adhan_prefs.dart';
import 'package:untitled/features/prayer/adhan_scheduler.dart';
import 'package:untitled/features/prayer/prayer_service.dart';
import 'package:untitled/features/prayer/qibla_sensor.dart';
import 'package:untitled/features/prayer/sun_position.dart';
import 'package:untitled/features/prayer/widgets/qibla_compass.dart';

// Cairo
const s = PrayerSettings(
    30.0444, 31.2357, CalculationMethod.egyptian, Madhab.shafi, true);

void main() {
  group('per-prayer alerts', () {
    final midnight = DateTime(2026, 3, 1);

    test('defaults keep the old behaviour: five adhans a day', () {
      final plan = AdhanScheduler.plan(s, midnight, days: 1);
      expect(plan, hasLength(5));
      expect(plan.every((a) => a.kind == AlertKind.adhan), isTrue);
    });

    test('off skips the prayer, notify changes the kind', () {
      final plan = AdhanScheduler.plan(s, midnight, days: 1, alerts: {
        Prayer.asr: const PrayerAlert(mode: AlertMode.off),
        Prayer.isha: const PrayerAlert(mode: AlertMode.notify),
      });
      expect(plan.map((a) => a.prayer), isNot(contains(Prayer.asr)));
      expect(plan.firstWhere((a) => a.prayer == Prayer.isha).kind, AlertKind.notify);
      expect(plan, hasLength(4));
    });

    test('a reminder comes N minutes before, in the reminder slot', () {
      final t = s.timesFor(midnight);
      final plan = AdhanScheduler.plan(s, midnight, days: 1, alerts: {
        Prayer.fajr: const PrayerAlert(reminderMinutes: 15),
      });
      final r = plan.firstWhere((a) => a.kind == AlertKind.reminder);
      expect(r.prayer, Prayer.fajr);
      expect(r.at, t.fajr.subtract(const Duration(minutes: 15)));
      expect(r.id, AdhanScheduler.idFor(0, 5)); // 205
      expect(r.minutesBefore, 15);
      expect(plan, hasLength(6));
    });

    test('reminder only, when the adhan is off', () {
      final plan = AdhanScheduler.plan(s, midnight, days: 1, alerts: {
        Prayer.dhuhr: const PrayerAlert(mode: AlertMode.off, reminderMinutes: 10),
      });
      final dhuhr = plan.where((a) => a.prayer == Prayer.dhuhr).toList();
      expect(dhuhr, hasLength(1));
      expect(dhuhr.single.kind, AlertKind.reminder);
    });

    test('a reminder already in the past is skipped', () {
      final t = s.timesFor(midnight);
      final now = t.asr.subtract(const Duration(minutes: 5));
      final plan = AdhanScheduler.plan(s, now, days: 1, alerts: {
        Prayer.asr: const PrayerAlert(reminderMinutes: 10),
      });
      expect(plan.where((a) => a.kind == AlertKind.reminder), isEmpty);
      expect(plan.first.prayer, Prayer.asr); // the adhan itself still comes
    });

    test('summary text', () {
      expect(const PrayerAlert().summary, 'أذان');
      expect(const PrayerAlert(mode: AlertMode.notify, reminderMinutes: 10).summary,
          'إشعار · تذكير قبلها بـ 10 د');
    });
  });

  group('compass smoothing', () {
    test('averages across north instead of spinning through 180', () {
      final f = HeadingSmoother(alpha: 0.5);
      f.add(359);
      final h = f.add(1);
      expect(h < 1 || h > 359, isTrue, reason: 'got $h');
    });

    test('jitter of +-5 settles near the true heading', () {
      final f = HeadingSmoother();
      var h = 0.0;
      for (var i = 0; i < 200; i++) {
        h = f.add(100 + (i.isEven ? 5 : -5));
      }
      expect(h, closeTo(100, 1));
    });
  });

  test('alignment latch: enter under 3, leave past 6, one tick per entry', () {
    final l = AlignmentLatch();
    final ticks = [10.0, 2.9, 5.0, 4.0, 6.1, 2.0].map(l.update).toList();
    expect(ticks, [false, true, false, false, false, true]);
    expect(l.aligned, isTrue);
  });

  test('compass accuracy from the plugin values', () {
    expect(CompassAccuracy.from(15), CompassAccuracy.high);
    expect(CompassAccuracy.from(30), CompassAccuracy.medium);
    expect(CompassAccuracy.from(45), CompassAccuracy.low);
    expect(CompassAccuracy.from(null), CompassAccuracy.unknown);
    expect(CompassAccuracy.low.needsCalibration, isTrue);
    expect(CompassAccuracy.medium.needsCalibration, isFalse);
  });

  group('sun position', () {
    test('Cairo at local noon: just past south, about 40 degrees up', () {
      final p = SunPosition.at(DateTime.utc(2026, 11, 18, 10), 30.0444, 31.2357);
      expect(p.azimuth, closeTo(186, 2));
      expect(p.altitude, closeTo(40.5, 1));
    });

    test('below the horizon at night', () {
      final p = SunPosition.at(DateTime.utc(2026, 11, 18, 22), 30.0444, 31.2357);
      expect(p.altitude, lessThan(0));
    });
  });

  test('direction names', () {
    expect(directionName(136), 'الجنوب الشرقي');
    expect(directionName(0), 'الشمال');
    expect(directionName(359), 'الشمال');
  });
}
