import 'package:adhan/adhan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:untitled/features/prayer/prayer_service.dart';

void main() {
  // Cairo
  const s = PrayerSettings(
      30.0444, 31.2357, CalculationMethod.egyptian, Madhab.shafi, false);

  test('prayer order and next prayer rolls past midnight', () {
    final t = s.timesFor(DateTime(2026, 3, 1));
    expect(t.fajr.isBefore(t.sunrise), isTrue);
    expect(t.sunrise.isBefore(t.dhuhr), isTrue);
    expect(t.dhuhr.isBefore(t.asr), isTrue);
    expect(t.asr.isBefore(t.maghrib), isTrue);
    expect(t.maghrib.isBefore(t.isha), isTrue);

    final (p1, at1) = nextPrayer(s, t.dhuhr.subtract(const Duration(minutes: 1)));
    expect(p1, Prayer.dhuhr);
    expect(at1, t.dhuhr);

    final (p2, at2) = nextPrayer(s, t.isha.add(const Duration(minutes: 1)));
    expect(p2, Prayer.fajr);
    expect(at2.day, 2); // tomorrow
  });

  test('hanafi asr is later than shafi', () {
    const h = PrayerSettings(
        30.0444, 31.2357, CalculationMethod.egyptian, Madhab.hanafi, false);
    final d = DateTime(2026, 3, 1);
    expect(h.timesFor(d).asr.isAfter(s.timesFor(d).asr), isTrue);
  });

  test('qibla from Cairo points south-east', () {
    final q = Qibla(s.coords).direction;
    expect(q, inInclusiveRange(130, 140)); // ~136°
  });

  group('sunrise is never the next prayer', () {
    final t = s.timesFor(DateTime(2026, 3, 1));

    test('between fajr and sunrise the next prayer is dhuhr', () {
      final (p, at) = nextPrayer(s, t.fajr.add(const Duration(minutes: 1)));
      expect(p, Prayer.dhuhr);
      expect(at, t.dhuhr);
    });

    test('right before sunrise it is still dhuhr', () {
      final (p, _) = nextPrayer(s, t.sunrise.subtract(const Duration(seconds: 1)));
      expect(p, Prayer.dhuhr);
    });

    test('before fajr the next prayer is today\'s fajr', () {
      final (p, at) = nextPrayer(s, t.fajr.subtract(const Duration(minutes: 1)));
      expect(p, Prayer.fajr);
      expect(at, t.fajr);
    });
  });

  group('previous prayer and progress', () {
    final t = s.timesFor(DateTime(2026, 3, 1));

    test('previous of mid-afternoon is dhuhr', () {
      final (p, at) = previousPrayer(s, t.asr.subtract(const Duration(minutes: 5)));
      expect(p, Prayer.dhuhr);
      expect(at, t.dhuhr);
    });

    test('exactly at a prayer time that prayer counts as previous', () {
      final (p, _) = previousPrayer(s, t.asr);
      expect(p, Prayer.asr);
    });

    test('before fajr the previous prayer is yesterday\'s isha', () {
      final (p, at) = previousPrayer(s, t.fajr.subtract(const Duration(minutes: 1)));
      expect(p, Prayer.isha);
      expect(at.day, 28); // 28 Feb 2026
    });

    test('progress is half way between dhuhr and asr', () {
      final mid = t.dhuhr.add(t.asr.difference(t.dhuhr) ~/ 2);
      expect(prayerProgress(s, mid), closeTo(0.5, 0.01));
    });

    test('progress spans fajr to dhuhr, skipping sunrise', () {
      expect(prayerProgress(s, t.sunrise), greaterThan(0));
      expect(prayerProgress(s, t.sunrise), lessThan(0.5));
    });
  });
}
