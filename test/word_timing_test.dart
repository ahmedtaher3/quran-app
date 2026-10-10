import 'package:flutter_test/flutter_test.dart';
import 'package:untitled/features/audio/quran_player.dart';

void main() {
  test('word at position', () {
    final t = VerseTiming('', [
      [0, 1, 80, 960],
      [1, 2, 970, 1800],
      [2, 3, 1810, 2460],
    ]);
    expect(t.wordAt(0), isNull); // before first word
    expect(t.wordAt(500), 1);
    expect(t.wordAt(965), 1); // gap: hold previous word
    expect(t.wordAt(1000), 2);
    expect(t.wordAt(2459), 3);
    expect(t.wordAt(9000), 3); // after last word: hold it
  });
}
