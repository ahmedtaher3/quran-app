import 'package:flutter_test/flutter_test.dart';
import 'package:untitled/features/search/search_index.dart';

void main() {
  final idx = [
    IndexedAyah(1, 1, 1, 1, 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ', 'أبدأ قراءة القرآن'),
    IndexedAyah(2, 1, 2, 1, 'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ', 'الثناء على الله'),
    IndexedAyah(8, 2, 3, 1, 'ٱلَّذِينَ يُؤْمِنُونَ بِٱلْغَيْبِ وَيُقِيمُونَ ٱلصَّلَوٰةَ', 'الصلاة والزكاة'),
    IndexedAyah(500, 4, 1, 4, 'يَٰٓأَيُّهَا ٱلنَّاسُ ٱتَّقُوا۟ رَبَّكُمُ', null),
  ];

  test('diacritics-insensitive with word highlight', () {
    final hits = search(idx, 'الرحيم');
    expect(hits.map((h) => h.ayah.id), [1]);
    expect(hits.first.highlight, {3});
  });

  test('multi-word any order, highlights both', () {
    final hits = search(idx, 'رب الحمد');
    expect(hits.map((h) => h.ayah.id), [2]);
    expect(hits.first.highlight, {0, 2});
  });

  test('typed without space across words', () {
    final hits = search(idx, 'الحمدلله');
    expect(hits.map((h) => h.ayah.id), [2]);
    expect(hits.first.highlight, {0, 1});
  });

  test('filters and tafsir scope', () {
    expect(search(idx, 'رب', sura: 4).map((h) => h.ayah.id), [500]);
    expect(search(idx, 'رب', juz: 1).map((h) => h.ayah.id), [2]);
    expect(search(idx, 'الزكاه', scope: SearchScope.tafsir).map((h) => h.ayah.id), [8]);
    expect(search(idx, '   '), isEmpty);
  });
}
