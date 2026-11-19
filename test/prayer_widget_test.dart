import 'package:adhan/adhan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:untitled/features/prayer/prayer_service.dart';
import 'package:untitled/features/prayer/widget_sync.dart';

void main() {
  const s = PrayerSettings(
      30.0444, 31.2357, CalculationMethod.egyptian, Madhab.shafi, true);

  test('payload: a week of six absolute times, in order', () {
    final now = DateTime(2026, 11, 18, 13);
    final p = WidgetSync.buildPayload(s, now, place: 'القاهرة', hijriAdjust: 0);
    expect(p['place'], 'القاهرة');
    expect(p['names'], ['الفجر', 'الشروق', 'الظهر', 'العصر', 'المغرب', 'العشاء']);
    final days = p['days'] as List;
    expect(days, hasLength(7));
    for (final d in days.cast<Map>()) {
      final t = (d['times'] as List).cast<int>();
      expect(t, hasLength(6));
      for (var i = 1; i < 6; i++) {
        expect(t[i], greaterThan(t[i - 1]));
      }
    }
    // day 0 is today: its fajr matches the app's own calculation
    final fajr = s.timesFor(now).fajr.millisecondsSinceEpoch;
    expect((days.first as Map)['times'][0], fajr);
    expect((days.first as Map)['hijri'], '8 جمادى الآخرة 1448 هـ');
  });

  test('widget uri routing', () {
    expect(WidgetSync.isPrayerUri(Uri.parse(WidgetSync.launchUri)), isTrue);
    expect(WidgetSync.isPrayerUri(Uri.parse('tarikquran://other')), isFalse);
    expect(WidgetSync.isPrayerUri(null), isFalse);
  });
}
