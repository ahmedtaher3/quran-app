import 'package:adhan/adhan.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:untitled/core/notifications.dart';
import 'package:untitled/features/prayer/adhan_scheduler.dart';
import 'package:untitled/features/prayer/prayer_clock.dart';
import 'package:untitled/features/prayer/prayer_service.dart';
import 'package:untitled/features/prayer/qibla_sensor.dart';

void main() {
  // Cairo
  const s = PrayerSettings(
      30.0444, 31.2357, CalculationMethod.egyptian, Madhab.shafi, true);

  group('adhan window', () {
    test('plans five adhans a day for seven days, sunrise excluded', () {
      final midnight = DateTime(2026, 3, 1);
      final plan = AdhanScheduler.plan(s, midnight);
      expect(plan, hasLength(35));
      expect(plan.where((a) => a.prayer == Prayer.sunrise), isEmpty);
      expect(plan.first.prayer, Prayer.fajr);
      expect(plan.last.at.day, 7);
    });

    test('ids are unique and stay inside the prayer range', () {
      final plan = AdhanScheduler.plan(s, DateTime(2026, 3, 1));
      final ids = plan.map((a) => a.id).toSet();
      expect(ids, hasLength(plan.length));
      for (final id in ids) {
        expect(id, inInclusiveRange(AdhanScheduler.baseId, AdhanScheduler.lastId));
      }
      // never collide with daily ayah (100..106) or the wird reminder (1)
      expect(ids.any((id) => id < 200), isFalse);
    });

    test('nothing is planned in the past', () {
      final t = s.timesFor(DateTime(2026, 3, 1));
      final now = t.asr.add(const Duration(minutes: 1));
      final plan = AdhanScheduler.plan(s, now);
      expect(plan.every((a) => a.at.isAfter(now)), isTrue);
      // today only maghrib and isha are left, then six full days
      expect(plan, hasLength(2 + 6 * 5));
      expect(plan.first.prayer, Prayer.maghrib);
    });

    test('slot id encodes day and prayer', () {
      expect(AdhanScheduler.idFor(0, 0), 200);
      expect(AdhanScheduler.idFor(1, 4), 214);
      expect(AdhanScheduler.idFor(6, 4), 264);
      expect(AdhanScheduler.lastId, 269);
    });
  });

  test('exact permission picks the alarm mode', () {
    expect(Notifications.scheduleModeFor(exact: true),
        AndroidScheduleMode.exactAllowWhileIdle);
    expect(Notifications.scheduleModeFor(exact: false),
        AndroidScheduleMode.inexactAllowWhileIdle);
  });

  group('list refresh boundaries', () {
    final t = s.timesFor(DateTime(2026, 3, 1));

    test('after fajr the next boundary is sunrise', () {
      expect(nextBoundary(s, t.fajr.add(const Duration(minutes: 1))), t.sunrise);
    });

    test('after isha the next boundary is midnight', () {
      expect(nextBoundary(s, t.isha.add(const Duration(minutes: 1))),
          DateTime(2026, 3, 2));
    });
  });

  group('true heading', () {
    test('adds east declination', () {
      expect(QiblaSensor.trueHeading(100, 4.6), closeTo(104.6, 1e-9));
    });

    test('wraps past north both ways', () {
      expect(QiblaSensor.trueHeading(358, 4), closeTo(2, 1e-9));
      expect(QiblaSensor.trueHeading(2, -4), closeTo(358, 1e-9));
    });
  });
}
