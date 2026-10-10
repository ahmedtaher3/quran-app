import 'dart:math';

import 'package:untitled/features/Koran/data/model/ayah.dart';

enum QuizType { complete, next, whichSura }

class Question {
  final QuizType type;
  final String prompt; // ayah text or its first half
  final List<String> options;
  final int answer; // index into options
  final Verse verse;
  const Question(this.type, this.prompt, this.options, this.answer, this.verse);
}

List<String> _words(String t) => t.split(RegExp(r'\s+'));

/// Builds [count] questions from [pool] (verses with suraName set).
/// Distractors come from the same sura when possible so they're plausible.
List<Question> buildQuiz(List<Verse> pool, {int count = 10, Random? rng}) {
  final r = rng ?? Random();
  final bySura = <int, List<Verse>>{};
  for (final v in pool) {
    (bySura[v.sura] ??= []).add(v);
  }
  final suraNames = {for (final v in pool) v.sura: v.suraName ?? 'سورة ${v.sura}'};

  final out = <Question>[];
  final used = <int>{};
  var guard = 0;
  while (out.length < count && guard++ < count * 20) {
    final v = pool[r.nextInt(pool.length)];
    if (used.contains(v.id)) continue;
    final siblings = bySura[v.sura]!;
    final type = QuizType.values[r.nextInt(QuizType.values.length)];
    final q = switch (type) {
      QuizType.complete => _complete(v, siblings, pool, r),
      QuizType.next => _next(v, siblings, pool, r),
      QuizType.whichSura => suraNames.length < 4 ? null : _sura(v, suraNames, r),
    };
    if (q == null) continue;
    used.add(v.id);
    out.add(q);
  }
  return out;
}

Question? _complete(Verse v, List<Verse> siblings, List<Verse> pool, Random r) {
  final w = _words(v.text);
  if (w.length < 4) return null;
  final cut = w.length ~/ 2;
  String tail(Verse x) {
    final xw = _words(x.text);
    return xw.skip(xw.length ~/ 2).join(' ');
  }

  final correct = w.skip(cut).join(' ');
  final candidates = [...siblings, ...pool]
      .where((x) => x.id != v.id && _words(x.text).length >= 4)
      .map(tail)
      .where((t) => t != correct)
      .toSet()
      .toList();
  return _assemble(QuizType.complete, '${w.take(cut).join(' ')} …', correct,
      candidates, v, r);
}

Question? _next(Verse v, List<Verse> siblings, List<Verse> pool, Random r) {
  final i = siblings.indexWhere((x) => x.id == v.id);
  if (i < 0 || i + 1 >= siblings.length) return null;
  final correct = siblings[i + 1].text;
  final candidates = [...siblings, ...pool]
      .where((x) => x.id != v.id && x.text != correct)
      .map((x) => x.text)
      .toSet()
      .toList();
  return _assemble(QuizType.next, v.text, correct, candidates, v, r);
}

Question? _sura(Verse v, Map<int, String> names, Random r) {
  final correct = names[v.sura]!;
  final candidates = names.values.where((n) => n != correct).toList();
  return _assemble(QuizType.whichSura, v.text, correct, candidates, v, r);
}

Question? _assemble(QuizType t, String prompt, String correct,
    List<String> candidates, Verse v, Random r) {
  if (candidates.length < 3) return null;
  candidates.shuffle(r);
  final options = [correct, ...candidates.take(3)]..shuffle(r);
  return Question(t, prompt, options, options.indexOf(correct), v);
}
