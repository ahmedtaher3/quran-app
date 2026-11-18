package com.tarik.al.quran

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import dev.fluttercommunity.workmanager.BackgroundWorker

/**
 * Replans the adhan window when its inputs change while the app is closed:
 * boot, app update, manual time or time-zone change, and the user granting
 * or revoking "Alarms & reminders".
 *
 * It hands the work to the workmanager plugin's worker, which runs the Dart
 * task `prayer_reschedule` (see lib/features/prayer/prayer_background.dart).
 */
class PrayerTimeChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // legacy shared_preferences store; nothing to plan if adhan is off
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        if (!prefs.getBoolean("flutter.prayer_notify", false)) return

        val work = OneTimeWorkRequestBuilder<BackgroundWorker>()
            .setInputData(workDataOf(BackgroundWorker.DART_TASK_KEY to "prayer_reschedule"))
            .build()
        WorkManager.getInstance(context)
            .enqueueUniqueWork("prayer_reschedule_now", ExistingWorkPolicy.REPLACE, work)
    }
}
