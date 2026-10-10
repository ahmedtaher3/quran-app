/// SM-2 spaced repetition for one memorized ayah.
class SrsCard {
  final int verseId;
  final int sura;
  final double ease;
  final int interval; // days
  final int reps;
  final DateTime due; // date only

  const SrsCard({
    required this.verseId,
    required this.sura,
    this.ease = 2.5,
    this.interval = 0,
    this.reps = 0,
    required this.due,
  });

  /// Strength 0..1 for UI: how settled this ayah is.
  double get strength => (interval / 30).clamp(0, 1).toDouble();

  bool isDue(DateTime today) => !due.isAfter(_date(today));

  Map<String, dynamic> toMap() => {
        'verse_id': verseId,
        'sura': sura,
        'ease': ease,
        'interval': interval,
        'reps': reps,
        'due': due.millisecondsSinceEpoch,
      };

  factory SrsCard.fromMap(Map<String, dynamic> m) => SrsCard(
        verseId: m['verse_id'],
        sura: m['sura'],
        ease: (m['ease'] as num).toDouble(),
        interval: m['interval'],
        reps: m['reps'],
        due: DateTime.fromMillisecondsSinceEpoch(m['due']),
      );
}

enum Grade { again, hard, good, easy }

DateTime _date(DateTime d) => DateTime(d.year, d.month, d.day);

/// Standard SM-2 with the 4-button mapping (again=1, hard=3, good=4, easy=5).
SrsCard review(SrsCard c, Grade g, DateTime today) {
  final q = switch (g) {
    Grade.again => 1,
    Grade.hard => 3,
    Grade.good => 4,
    Grade.easy => 5,
  };
  var ease = c.ease + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
  if (ease < 1.3) ease = 1.3;

  int reps, interval;
  if (q < 3) {
    reps = 0;
    interval = 1; // see it again tomorrow
  } else {
    reps = c.reps + 1;
    interval = switch (reps) {
      1 => 1,
      2 => g == Grade.easy ? 4 : 3,
      _ => (c.interval * ease * (g == Grade.hard ? 0.8 : 1)).round(),
    };
    if (interval < 1) interval = 1;
  }
  final d = _date(today);
  return SrsCard(
    verseId: c.verseId,
    sura: c.sura,
    ease: ease,
    interval: interval,
    reps: reps,
    due: DateTime(d.year, d.month, d.day + interval),
  );
}

/// Opening third of the ayah (at least one word), then an ellipsis:
/// enough to trigger recall without giving the ayah away.
String openingHint(String text) {
  final words = text.split(RegExp(r'\s+'));
  final n = (words.length / 3).floor().clamp(1, words.length);
  return n >= words.length ? text : '${words.take(n).join(' ')} …';
}
