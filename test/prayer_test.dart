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
}
