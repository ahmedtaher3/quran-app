/// Compares what speech recognition heard against the expected ayah words.
enum WordState { pending, correct, missed }

final _diacritics = RegExp(r'[ؐ-ًؚ-ٰٟۖ-ۭـ]');

/// Folds spelling variants speech engines and mushaf spelling disagree on.
String normalizeArabic(String s) => s
    .replaceAll(_diacritics, '')
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ة', 'ه')
    .replaceAll('ؤ', 'و')
    .replaceAll('ئ', 'ي')
    .replaceAll('ء', '')
    .replaceAll(RegExp(r'[^ء-ي\s]'), '')
    .trim();

List<String> tokens(String s) => normalizeArabic(s)
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .toList();

int _edit(String a, String b) {
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = [i, ...List.filled(b.length, 0)];
    for (var j = 1; j <= b.length; j++) {
      cur[j] = [
        prev[j] + 1,
        cur[j - 1] + 1,
        prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
      ].reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}

/// Same word, allowing one slip for longer words (speech engines often
/// drop or swap a letter: الرحمان/الرحمن, يومنون/يؤمنون).
/// [lenient] (children's unclear speech): 2 slips from 5 letters, 1 from 3.
bool sameWord(String a, String b, {bool lenient = false}) {
  if (a == b) return true;
  final n = a.length < b.length ? a.length : b.length;
  final allowed = lenient
      ? (n >= 5
          ? 2
          : n >= 3
              ? 1
              : 0)
      : (n >= 4 ? 1 : 0);
  return allowed > 0 && _edit(a, b) <= allowed;
}

/// Aligns [heard] to [expected] (both normalized tokens) with LCS.
/// Expected words matched -> correct; unmatched words before the last
/// matched one -> missed (skipped or wrong); the rest -> pending.
List<WordState> align(List<String> expected, List<String> heard,
    {bool lenient = false}) {
  bool same(String a, String b) => sameWord(a, b, lenient: lenient);
  final n = expected.length, m = heard.length;
  final dp = List.generate(n + 1, (_) => List.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      dp[i][j] = same(expected[i], heard[j])
          ? dp[i + 1][j + 1] + 1
          : (dp[i + 1][j] > dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1]);
    }
  }
  final out = List.filled(n, WordState.pending);
  var i = 0, j = 0, lastMatch = -1;
  while (i < n && j < m) {
    if (same(expected[i], heard[j])) {
      out[i] = WordState.correct;
      lastMatch = i;
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }
  for (var k = 0; k < lastMatch; k++) {
    if (out[k] == WordState.pending) out[k] = WordState.missed;
  }
  return out;
}
