import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:untitled/core/app_theme.dart';
import 'package:untitled/features/prayer/prayer_service.dart';
import 'package:untitled/features/prayer/widgets/time_format.dart';

const _icons = {
  Prayer.fajr: Icons.wb_twilight_rounded,
  Prayer.sunrise: Icons.wb_sunny_outlined,
  Prayer.dhuhr: Icons.light_mode_rounded,
  Prayer.asr: Icons.sunny,
  Prayer.maghrib: Icons.nights_stay_rounded,
  Prayer.isha: Icons.bedtime_rounded,
};

/// The six times of the day: done prayers fade, the next one is
/// highlighted, sunrise is shown for reference only. Rebuilt by
/// PrayerClock at each boundary, not every second.
class PrayerTimesList extends StatelessWidget {
  final PrayerSettings settings;
  final DateTime now;
  const PrayerTimesList({super.key, required this.settings, required this.now});

  @override
  Widget build(BuildContext context) {
    final t = settings.timesFor(now);
    final (next, at) = nextPrayer(settings, now);
    final tomorrow = at.day != now.day; // after isha: tomorrow's fajr
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          for (final p in const [
            Prayer.fajr,
            Prayer.sunrise,
            Prayer.dhuhr,
            Prayer.asr,
            Prayer.maghrib,
            Prayer.isha,
          ])
            _Row(
              prayer: p,
              time: p == next && tomorrow ? at : t.timeForPrayer(p)!,
              isNext: p == next,
              tomorrow: tomorrow,
              past: p != next && !t.timeForPrayer(p)!.isAfter(now),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final Prayer prayer;
  final DateTime time;
  final bool isNext, past, tomorrow;
  const _Row({
    required this.prayer,
    required this.time,
    required this.isNext,
    required this.past,
    required this.tomorrow,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final sunrise = prayer == Prayer.sunrise;
    final fade = past ? 0.5 : 1.0;
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: isNext ? AppColors.tealSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Opacity(
        opacity: fade,
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isNext ? primary : AppColors.tealSoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(_icons[prayer],
                  size: 19,
                  color: isNext ? Theme.of(context).colorScheme.onPrimary : primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(prayerNames[prayer]!,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: isNext ? FontWeight.bold : FontWeight.w500,
                          color: AppColors.text)),
                  if (sunrise)
                    Text('للعلم، ليس وقت صلاة',
                        style: TextStyle(fontSize: 11.5, color: AppColors.subtle)),
                  if (isNext)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB300),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(tomorrow ? 'غدًا' : 'القادمة',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF3A2A00),
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
            Text(prayerTime(context, time),
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: isNext ? FontWeight.bold : FontWeight.w500,
                    color: AppColors.text,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
      ),
    );
  }
}
