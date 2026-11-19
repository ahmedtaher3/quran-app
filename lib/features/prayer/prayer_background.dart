import 'dart:io';

import 'package:workmanager/workmanager.dart';
import 'package:untitled/features/prayer/adhan_scheduler.dart';
import 'package:untitled/features/prayer/prayer_service.dart';

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
    // Always: PrayerTimeChangeReceiver needs the dispatcher handle saved.
    await Workmanager().initialize(prayerBackgroundDispatcher);
    await ensurePeriodic();
  }

  /// The 12-hour job only for people who use prayer times (a saved
  /// location); otherwise it would start a Flutter engine twice a day for
  /// nothing. Called again once a location is first saved.
  static Future<void> ensurePeriodic() async {
    if (!Platform.isAndroid) return;
    if (await PrayerStore.load() == null) {
      await Workmanager().cancelByUniqueName('prayer_daily');
      return;
    }
    await Workmanager().registerPeriodicTask(
      'prayer_daily',
      prayerRescheduleTask,
      frequency: const Duration(hours: 12),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }
}
