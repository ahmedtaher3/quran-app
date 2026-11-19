package com.tarik.al.quran

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale

/**
 * Home-screen prayer widget in three sizes. Data is a week of absolute
 * times written by WidgetSync (Dart); this class never runs Dart.
 *
 * Battery: no updatePeriodMillis. The countdown is a Chronometer the
 * system ticks by itself, and one non-waking alarm redraws the widget at
 * the next prayer (or midnight), delivered whenever the device is awake.
 */
class PrayerWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val data = PrayerWeek.parse(widgetData.getString(PAYLOAD_KEY, null))
        val now = System.currentTimeMillis()
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, views(context, appWidgetManager, id, data, now))
        }
        scheduleRefresh(context, data, now)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        // resized: below Android 12 the layout is picked here
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_REFRESH, Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_DATE_CHANGED, Intent.ACTION_BOOT_COMPLETED -> refreshAll(context)
            else -> super.onReceive(context, intent)
        }
    }

    private fun views(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        data: PrayerWeek?,
        now: Long,
    ): RemoteViews {
        val small = build(context, R.layout.prayer_widget_small, data, now)
        val medium = build(context, R.layout.prayer_widget_medium, data, now)
        val large = build(context, R.layout.prayer_widget_large, data, now)
        if (Build.VERSION.SDK_INT >= 31) {
            // the launcher picks the largest one that fits each size
            return RemoteViews(
                mapOf(
                    SizeF(110f, 40f) to small,
                    SizeF(250f, 60f) to medium,
                    SizeF(250f, 150f) to large,
                ),
            )
        }
        val o = manager.getAppWidgetOptions(id)
        val w = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val h = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
        return when {
            w >= 250 && h >= 150 -> large
            w >= 250 -> medium
            else -> small
        }
    }

    private fun build(context: Context, layout: Int, data: PrayerWeek?, now: Long): RemoteViews {
        val v = RemoteViews(context.packageName, layout)
        v.setOnClickPendingIntent(
            R.id.pw_root,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(LAUNCH_URI)),
        )
        val next = data?.next(now)
        if (data == null || next == null) {
            // no data yet, or the week ran out without the app being opened
            v.setTextViewText(R.id.pw_name, context.getString(R.string.prayer_widget_stale))
            v.setViewVisibility(R.id.pw_time, View.GONE)
            v.setViewVisibility(R.id.pw_countdown, View.GONE)
            return v
        }
        v.setViewVisibility(R.id.pw_time, View.VISIBLE)
        v.setViewVisibility(R.id.pw_countdown, View.VISIBLE)
        val tomorrow = !sameDay(next.at, now)
        v.setTextViewText(R.id.pw_name, data.names[next.index])
        v.setTextViewText(
            R.id.pw_time,
            clock(context, next.at) + if (tomorrow) " · غدًا" else "",
        )
        v.setChronometer(R.id.pw_countdown, SystemClock.elapsedRealtime() + (next.at - now), null, true)
        v.setChronometerCountDown(R.id.pw_countdown, true)

        if (layout == R.layout.prayer_widget_large) {
            v.setTextViewText(R.id.pw_header, "${data.place} · ${data.days[next.day].hijri}")
            val prev = data.previous(now)
            if (prev != null) {
                val p = ((now - prev.at) * 1000 / (next.at - prev.at)).toInt().coerceIn(0, 1000)
                v.setProgressBar(R.id.pw_progress, 1000, p, false)
            }
        }
        if (layout != R.layout.prayer_widget_small) {
            val day = data.days[next.day]
            PRAYERS.forEachIndexed { cell, i ->
                v.setTextViewText(CELL_NAMES[cell], data.names[i])
                v.setTextViewText(CELL_TIMES[cell], clock(context, day.times[i], suffix = false))
                v.setInt(
                    CELLS[cell], "setBackgroundResource",
                    if (i == next.index) R.drawable.pw_cell_on else R.drawable.pw_cell_off,
                )
            }
        }
        return v
    }

    companion object {
        const val PAYLOAD_KEY = "prayer_widget"
        const val LAUNCH_URI = "tarikquran://prayer"
        const val ACTION_REFRESH = "com.tarik.al.quran.PRAYER_WIDGET_REFRESH"

        /** Indexes of the five prayers in the payload; 1 is sunrise. */
        val PRAYERS = intArrayOf(0, 2, 3, 4, 5)
        private val CELLS = intArrayOf(R.id.pw_cell0, R.id.pw_cell1, R.id.pw_cell2, R.id.pw_cell3, R.id.pw_cell4)
        private val CELL_NAMES = intArrayOf(R.id.pw_cname0, R.id.pw_cname1, R.id.pw_cname2, R.id.pw_cname3, R.id.pw_cname4)
        private val CELL_TIMES = intArrayOf(R.id.pw_ctime0, R.id.pw_ctime1, R.id.pw_ctime2, R.id.pw_ctime3, R.id.pw_ctime4)

        fun refreshAll(context: Context) {
            val m = AppWidgetManager.getInstance(context)
            val ids = m.getAppWidgetIds(ComponentName(context, PrayerWidgetProvider::class.java))
            if (ids.isEmpty()) return
            context.sendBroadcast(
                Intent(context, PrayerWidgetProvider::class.java)
                    .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids),
            )
        }

        fun sameDay(a: Long, b: Long): Boolean {
            val x = Calendar.getInstance().apply { timeInMillis = a }
            val y = Calendar.getInstance().apply { timeInMillis = b }
            return x.get(Calendar.YEAR) == y.get(Calendar.YEAR) &&
                x.get(Calendar.DAY_OF_YEAR) == y.get(Calendar.DAY_OF_YEAR)
        }

        /** "4:58 م" kept in order inside RTL text; honours 24-hour mode. */
        fun clock(context: Context, at: Long, suffix: Boolean = true): String {
            val c = Calendar.getInstance().apply { timeInMillis = at }
            val h = c.get(Calendar.HOUR_OF_DAY)
            // Locale.US: "%02d" follows the device locale (Arabic-Indic digits)
            val mm = String.format(Locale.US, "%02d", c.get(Calendar.MINUTE))
            if (android.text.format.DateFormat.is24HourFormat(context)) {
                return "⁦${String.format(Locale.US, "%02d", h)}:$mm⁩"
            }
            val h12 = if (h % 12 == 0) 12 else h % 12
            val t = "⁦$h12:$mm⁩"
            return if (suffix) "$t ${if (h < 12) "ص" else "م"}" else t
        }

        /** One non-waking alarm at the next prayer (or midnight, for the date). */
        private fun scheduleRefresh(context: Context, data: PrayerWeek?, now: Long) {
            val midnight = Calendar.getInstance().apply {
                timeInMillis = now
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 1); set(Calendar.MILLISECOND, 0)
            }.timeInMillis
            val at = minOf(data?.next(now)?.at?.plus(1000) ?: midnight, midnight)
            val pi = PendingIntent.getBroadcast(
                context, 0,
                Intent(context, PrayerWidgetProvider::class.java).setAction(ACTION_REFRESH),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            // RTC, not RTC_WAKEUP: never wakes the device. A plain set() may be
            // deferred up to an hour, leaving the passed prayer on screen with
            // the countdown running negative; ask for an exact time when the
            // user allowed it, else a 10-minute window (the API 31+ minimum).
            try {
                if (Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()) {
                    am.setExact(AlarmManager.RTC, at, pi)
                    return
                }
            } catch (_: SecurityException) {
                // permission revoked between the check and the call
            }
            am.setWindow(AlarmManager.RTC, at, 10 * 60_000L, pi)
        }
    }
}

/** The week WidgetSync writes; see lib/features/prayer/widget_sync.dart. */
class PrayerWeek(val place: String, val names: List<String>, val days: List<Day>) {
    class Day(val hijri: String, val times: LongArray)
    class Slot(val day: Int, val index: Int, val at: Long)

    fun next(now: Long): Slot? {
        days.forEachIndexed { d, day ->
            for (i in PrayerWidgetProvider.PRAYERS) if (day.times[i] > now) return Slot(d, i, day.times[i])
        }
        return null
    }

    fun previous(now: Long): Slot? {
        var last: Slot? = null
        days.forEachIndexed { d, day ->
            for (i in PrayerWidgetProvider.PRAYERS) if (day.times[i] <= now) last = Slot(d, i, day.times[i])
        }
        return last
    }

    companion object {
        fun parse(json: String?): PrayerWeek? = try {
            val o = JSONObject(json ?: return null)
            val names = o.getJSONArray("names").let { a -> List(a.length()) { a.getString(it) } }
            val days = o.getJSONArray("days").let { a ->
                List(a.length()) { i ->
                    val d = a.getJSONObject(i)
                    val t = d.getJSONArray("times")
                    Day(d.getString("hijri"), LongArray(t.length()) { t.getLong(it) })
                }
            }
            PrayerWeek(o.getString("place"), names, days)
        } catch (e: Exception) {
            null
        }
    }
}
