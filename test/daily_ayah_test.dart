import 'package:flutter_test/flutter_test.dart';
import 'package:untitled/features/daily/daily_ayah.dart';

void main() {
  test('ayah of day is stable, in range, and varies', () {
    final d = DateTime(2026, 10, 10, 23, 59);
    expect(ayahIdFor(d), ayahIdFor(DateTime(2026, 10, 10, 0, 1)));
    final ids = {for (var i = 0; i < 365; i++) ayahIdFor(DateTime(2026, 1, 1 + i))};
    expect(ids.every((id) => id >= 1 && id <= 6236), isTrue);
    expect(ids.length, greaterThan(350)); // almost no repeats in a year
  });
}
