import 'package:flutter_test/flutter_test.dart';
import 'package:untitled/features/khatma/khatma.dart';

void main() {
  test('khatma schedule math', () {
    final start = DateTime(2026, 1, 1, 22); // late start still counts as day 1
    final k = Khatma(days: 30, start: start);
    expect(k.dailyPages, 21); // ceil(604/30)
    expect(k.wirdStart, 1);
    expect(k.wirdEnd, 21);
    expect(k.dayNumber(DateTime(2026, 1, 1, 8)), 1);
    expect(k.dayNumber(DateTime(2026, 1, 3)), 3);
    expect(k.pagesBehind(DateTime(2026, 1, 1)), 0); // today not overdue
    expect(k.pagesBehind(DateTime(2026, 1, 3)), 42);

    final ahead = k.copyWith(currentPage: 64); // 63 pages done on day 2
    expect(ahead.doneToday(DateTime(2026, 1, 2)), isTrue);
    expect(k.doneToday(DateTime(2026, 1, 1)), isFalse);
    expect(ahead.pagesBehind(DateTime(2026, 1, 2)), 21 - 63);

    final last = k.copyWith(currentPage: 600);
    expect(last.wirdEnd, 604); // clamped to mushaf end
    expect(last.copyWith(currentPage: last.wirdEnd + 1).finished, isTrue);
    expect(k.daysLeft(DateTime(2026, 3, 1)), 0);
  });
}
