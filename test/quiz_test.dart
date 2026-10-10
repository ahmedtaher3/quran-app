import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:untitled/features/Koran/data/model/ayah.dart';
import 'package:untitled/features/quiz/quiz.dart';

Verse _v(int id, int sura, int aya) => Verse(
      id: id,
      sura: sura,
      suraName: 'S$sura',
      ayaNumber: aya,
      page: 1,
      manzil: 1,
      ruku: 1,
      sajda: 0,
      hizbQuarter: 1,
      text: 'w$id a$id b$id c$id d$id e$id',
      audio: '',
    );

void main() {
  test('quiz questions are well-formed', () {
    final pool = [
      for (var s = 1; s <= 5; s++)
        for (var a = 1; a <= 6; a++) _v(s * 100 + a, s, a)
    ];
    final qs = buildQuiz(pool, count: 10, rng: Random(1));
    expect(qs.length, 10);
    expect(qs.map((q) => q.verse.id).toSet().length, 10); // no repeats
    for (final q in qs) {
      expect(q.options.length, 4);
      expect(q.options.toSet().length, 4); // distinct options
      final right = q.options[q.answer];
      switch (q.type) {
        case QuizType.whichSura:
          expect(right, q.verse.suraName);
        case QuizType.next:
          final next = pool.firstWhere((v) => v.id == q.verse.id + 1);
          expect(right, next.text);
        case QuizType.complete:
          expect('${q.prompt.replaceAll(' …', '')} $right', q.verse.text);
      }
    }
  });

  test('tiny pool does not loop forever', () {
    expect(buildQuiz([_v(1, 1, 1)], count: 5), isEmpty);
  });
}
