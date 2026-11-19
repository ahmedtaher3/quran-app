import 'package:adhan/adhan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled/core/notifications.dart';
import 'package:untitled/features/prayer/adhan_prefs.dart';
import 'package:untitled/features/prayer/prayer_service.dart';

enum AlertKind { adhan, notify, reminder }

/// One planned prayer notification.
class PlannedAdhan {
  final int id;
  final Prayer prayer;
  final DateTime at;
  final AlertKind kind;

  /// Minutes before the prayer, for reminders.
  final int minutesBefore;
  const PlannedAdhan(this.id, this.prayer, this.at,
      {this.kind = AlertKind.adhan, this.minutesBefore = 0});
}

/// Keeps a rolling window of adhan alarms planned ahead, so the adhan keeps
/// coming even if the prayer screen is never opened.
///
/// Every trigger calls [reschedule] or [scheduleFor]: app start, a settings
/// change, the background job, boot or time change (native receiver), and
/// an exact-alarm permission change. It is idempotent: it clears whatever
/// is pending in the prayer id range, then plans the window again.
class AdhanScheduler {
  static const baseId = 200;
  static const days = 7;

  /// Per day: slots 0-4 are the five adhans, 5-9 are kept for reminders.
  static const slotsPerDay = 10;
  static const lastId = baseId + days * slotsPerDay - 1; // 269

  static const staleAfter = Duration(hours: 12);
  static const _lastRunKey = 'prayer_last_reschedule';
  static const _exactKey = 'prayer_exact_mode';

  static int idFor(int day, int slot) => baseId + day * slotsPerDay + slot;

  /// Notifications still ahead of [now] over [days] days, in time order.
  /// Each prayer follows its [alerts] entry; missing = adhan, no reminder.
  static List<PlannedAdhan> plan(PrayerSettings s, DateTime now,
      {int days = days, Map<Prayer, PrayerAlert> alerts = const {}}) {
    final out = <PlannedAdhan>[];
    for (var d = 0; d < days; d++) {
      final t = s.timesFor(DateTime(now.year, now.month, now.day + d));
      for (var i = 0; i < fivePrayers.length; i++) {
        final p = fivePrayers[i];
        final at = t.timeForPrayer(p)!;
        final a = alerts[p] ?? const PrayerAlert();
        final pre = a.reminderMinutes;
        if (pre > 0) {
          final when = at.subtract(Duration(minutes: pre));
          if (when.isAfter(now)) {
            out.add(PlannedAdhan(idFor(d, 5 + i), p, when,
                kind: AlertKind.reminder, minutesBefore: pre));
          }
        }
        if (a.mode != AlertMode.off && at.isAfter(now)) {
          out.add(PlannedAdhan(idFor(d, i), p, at,
              kind: a.mode == AlertMode.adhan ? AlertKind.adhan : AlertKind.notify));
        }
      }
    }
    return out;
  }

  /// Replans from the saved settings; no-op before a location was saved.
  static Future<void> reschedule() async {
    final s = await PrayerStore.load();
    if (s == null) return;
    await scheduleFor(s);
  }

  static Future<void> scheduleFor(PrayerSettings s) async {
    await Notifications.cancelPendingInRange(baseId, lastId);
    final exact = s.notify && await Notifications.canScheduleExact();
    if (s.notify) {
      final alerts = await AdhanPrefs.load();
      for (final a in plan(s, DateTime.now(), alerts: alerts)) {
        final name = prayerNames[a.prayer];
        await Notifications.scheduleAdhan(
          id: a.id,
          at: a.at,
          title: a.kind == AlertKind.reminder
              ? "بعد ${a.minutesBefore} دقيقة: صلاة $name"
              : "حان الآن موعد صلاة $name",
          body: a.kind == AlertKind.reminder
              ? "تذكير قبل الصلاة"
              : "حيّ على الصلاة، حيّ على الفلاح",
          exact: exact,
          channel: switch (a.kind) {
            AlertKind.adhan => PrayerChannel.adhan,
            AlertKind.notify => PrayerChannel.notify,
            AlertKind.reminder => PrayerChannel.reminder,
          },
        );
      }
    }
    final p = await SharedPreferences.getInstance();
    await p.setInt(_lastRunKey, DateTime.now().millisecondsSinceEpoch);
    await p.setBool(_exactKey, exact);
  }

  static const testId = 299;

  /// "Try the adhan": same channel and alarm mode as a real one, a few
  /// seconds from now, so the user can check sound and permissions.
  static Future<void> scheduleTest(
      {Duration after = const Duration(seconds: 5)}) async {
    await Notifications.scheduleAdhan(
      id: testId,
      at: DateTime.now().add(after),
      title: "أذان تجريبي",
      body: "هكذا يصلك تنبيه دخول وقت الصلاة",
      exact: await Notifications.canScheduleExact(),
    );
  }

  /// Cheap check for app resume: replans only when the window is getting
  /// old, or the exact-alarm permission changed since the last run (the
  /// user just came back from the system settings page).
  static Future<void> ensureFresh() async {
    final s = await PrayerStore.load();
    if (s == null) return;
    final p = await SharedPreferences.getInstance();
    final last = p.getInt(_lastRunKey);
    final stale = last == null ||
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(last)) >
            staleAfter;
    final exactNow = s.notify && await Notifications.canScheduleExact();
    if (stale || exactNow != (p.getBool(_exactKey) ?? false)) {
      await scheduleFor(s);
    }
  }
}
