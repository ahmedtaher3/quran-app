import 'package:flutter_test/flutter_test.dart';
import 'package:untitled/features/recite/matcher.dart';

void main() {
  const c = WordState.correct, m = WordState.missed, p = WordState.pending;

  test('normalize folds mushaf vs speech spellings', () {
    expect(normalizeArabic('ٱلْحَمْدُ'), 'الحمد');
    expect(normalizeArabic('إِيَّاكَ'), 'اياك');
    expect(normalizeArabic('الصلاة'), 'الصلاه');
    expect(sameWord('الرحمان', 'الرحمن'), isTrue);
    expect(sameWord('يومنون', 'يؤمنون'.replaceAll('ؤ', 'و')), isTrue);
    expect(sameWord('رب', 'رد'), isFalse); // short words must match exactly
  });

  test('align marks progress, skips and pending', () {
    final exp = tokens('الذين يؤمنون بالغيب ويقيمون الصلاة');
    expect(align(exp, []), [p, p, p, p, p]);
    expect(align(exp, tokens('الذين يومنون')), [c, c, p, p, p]);
    // skipped بالغيب
    expect(align(exp, tokens('الذين يومنون ويقيمون')), [c, c, m, c, p]);
    // extra noise words are ignored
    expect(align(exp, tokens('اه الذين يعني يومنون بالغيب ويقيمون الصلاه')),
        [c, c, c, c, c]);
  });

  test('lenient mode accepts unclear child speech', () {
    expect(sameWord('الصراط', 'السرات'), isFalse); // 2 slips: strict rejects
    expect(sameWord('الصراط', 'السرات', lenient: true), isTrue);
    expect(sameWord('رب', 'رد', lenient: true), isFalse); // short stays exact
    expect(sameWord('نعبد', 'نعبط', lenient: true), isTrue);
    final exp = tokens('اهدنا الصراط المستقيم');
    expect(align(exp, tokens('اهدنا السرات المستكيم'), lenient: true),
        [WordState.correct, WordState.correct, WordState.correct]);
  });
}
