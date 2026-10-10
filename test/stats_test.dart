import 'package:flutter_test/flutter_test.dart';
import 'package:untitled/features/stats/stats.dart';

void main() {
  test('streaks', () {
    final today = DateTime(2026, 3, 2);
    // run crossing a month boundary: Feb 27, 28, Mar 1
    final days = {'2026-02-27', '2026-02-28', '2026-03-01', '2026-01-10'};
    expect(currentStreak(days, today), 3); // today not read yet: from yesterday
    expect(currentStreak({...days, '2026-03-02'}, today), 4);
    expect(currentStreak({'2026-02-27'}, today), 0);
    expect(longestStreak(days), 3);
    expect(longestStreak({}), 0);

    final week = lastDays({'2026-03-01': 12}, today, 7);
    expect(week.length, 7);
    expect(week.last.day, DateTime(2026, 3, 2));
    expect(week[5].verses, 12);
  });
}
