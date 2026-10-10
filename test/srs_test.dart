import 'package:flutter_test/flutter_test.dart';
import 'package:untitled/features/hifz/srs.dart';

void main() {
  final today = DateTime(2026, 5, 1, 21);

  test('sm2 progression', () {
    var c = SrsCard(verseId: 1, sura: 1, due: DateTime(2026, 5, 1));
    expect(c.isDue(today), isTrue);

    c = review(c, Grade.good, today);
    expect(c.interval, 1);
    expect(c.due, DateTime(2026, 5, 2));
    expect(c.isDue(today), isFalse);

    c = review(c, Grade.good, today);
    expect(c.interval, 3);

    c = review(c, Grade.good, today);
    expect(c.interval, (3 * c.ease).round());

    final forgot = review(c, Grade.again, today);
    expect(forgot.reps, 0);
    expect(forgot.interval, 1);
    expect(forgot.ease, lessThan(c.ease));

    var floor = c;
    for (var i = 0; i < 20; i++) {
      floor = review(floor, Grade.again, today);
    }
    expect(floor.ease, 1.3);
  });

  test('opening hint', () {
    expect(openingHint('a b c d e f'), 'a b …');
    expect(openingHint('a b'), 'a …');
    expect(openingHint('a'), 'a');
  });
}
