import 'package:untitled/features/recite/matcher.dart' show normalizeArabic;

/// One searchable ayah: original words plus their normalized forms joined
/// by single spaces, so a char offset in [norm] maps back to a word index.
class IndexedAyah {
  final int id, sura, aya, juz;
  final String text;
  final List<String> words;
  final String norm;
  final String tafsirNorm;
  final List<int> _wordStarts;

  IndexedAyah(this.id, this.sura, this.aya, this.juz, this.text,
      String? tafsir)
      : words = text.split(RegExp(r'\s+')),
        norm = _join(text),
        tafsirNorm = tafsir == null ? '' : normalizeArabic(tafsir),
        _wordStarts = _starts(text);

  static String _join(String t) =>
      t.split(RegExp(r'\s+')).map(normalizeArabic).join(' ');

  static List<int> _starts(String t) {
    final out = <int>[];
    var pos = 0;
    for (final w in t.split(RegExp(r'\s+'))) {
      out.add(pos);
      pos += normalizeArabic(w).length + 1;
    }
    return out;
  }

  /// Word indices covered by [start, end) in [norm].
  Set<int> wordsIn(int start, int end) => {
        for (var i = 0; i < _wordStarts.length; i++)
          if (_wordStarts[i] < end &&
              (i + 1 == _wordStarts.length ? norm.length : _wordStarts[i + 1] - 1) >
                  start)
            i
      };
}

enum SearchScope { text, tafsir }

class SearchHit {
  final IndexedAyah ayah;
  final Set<int> highlight; // word indices
  SearchHit(this.ayah, this.highlight);
}

/// Every query word must appear (any order); a word typed without spaces
/// across a boundary (e.g. الحمدلله) still matches.
List<SearchHit> search(List<IndexedAyah> index, String query,
    {SearchScope scope = SearchScope.text, int? sura, int? juz}) {
  final q = query.split(RegExp(r'\s+')).map(normalizeArabic).where((w) => w.isNotEmpty).toList();
  if (q.isEmpty) return [];
  final out = <SearchHit>[];
  for (final a in index) {
    if (sura != null && a.sura != sura) continue;
    if (juz != null && a.juz != juz) continue;
    if (scope == SearchScope.tafsir) {
      if (q.every(a.tafsirNorm.contains)) out.add(SearchHit(a, const {}));
      continue;
    }
    final hl = <int>{};
    var ok = true;
    for (final w in q) {
      final i = a.norm.indexOf(w);
      if (i >= 0) {
        hl.addAll(a.wordsIn(i, i + w.length));
        continue;
      }
      // fallback: ignore spaces in the ayah
      final squashed = a.norm.replaceAll(' ', '');
      final j = squashed.indexOf(w);
      if (j < 0) {
        ok = false;
        break;
      }
      // map squashed offset back: count non-space chars
      var seen = 0, start = -1, end = -1;
      for (var k = 0; k < a.norm.length; k++) {
        if (a.norm[k] == ' ') continue;
        if (seen == j) start = k;
        if (seen == j + w.length - 1) {
          end = k + 1;
          break;
        }
        seen++;
      }
      if (start >= 0 && end > start) hl.addAll(a.wordsIn(start, end));
    }
    if (ok) out.add(SearchHit(a, hl));
  }
  return out;
}
