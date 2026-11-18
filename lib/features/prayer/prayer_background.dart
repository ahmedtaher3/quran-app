import 'dart:io';

import 'package:workmanager/workmanager.dart';
import 'package:untitled/features/prayer/adhan_scheduler.dart';

/// Task name the native PrayerTimeChangeReceiver also enqueues (boot,
/// time or time-zone change, exact-alarm permission change). Keep the two
/// in sync.
const prayerRescheduleTask = 'prayer_reschedule';

@pragma('vm:entry-point')
void prayerBackgroundDispatcher() {
  Workmanager().executeTask((task, _) async {
    try {
      await AdhanScheduler.reschedule();
      return true;
    } catch (_) {
      return false; // WorkManager retries with backoff
    }
  });
}

/// Rolls the adhan window forward even when the app is never opened.
class PrayerBackground {
  static Future<void> init() async {
    if (!Platform.isAndroid) return; // iOS needs BGTask setup; out of scope
    await Workmanager().initialize(prayerBackgroundDispatcher);
    await Workmanager().registerPeriodicTask(
      'prayer_daily',
      prayerRescheduleTask,
      frequency: const Duration(hours: 12),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }
}
