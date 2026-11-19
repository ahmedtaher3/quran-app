import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Which prayer channel a notification goes to.
enum PrayerChannel { adhan, notify, reminder }

/// "Stop adhan" is handled natively (the plugin cancels the notification,
/// which stops its sound); the plugin still wants a Dart entry point for
/// actions that arrive while the app is closed.
@pragma('vm:entry-point')
void notificationBackgroundResponse(NotificationResponse response) {}

/// Thin wrapper: daily reminders by fixed id.
class Notifications {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const wirdReminderId = 1;
  static const dailyAyahBaseId = 100; // 100..106, one per upcoming day

  /// Adhan gets its own channel so muting "آية اليوم" never mutes it.
  /// Channel sound can't change after creation; a new sound = a new id.
  static const adhanChannelId = 'prayer_adhan_system_v1';
  static const prayerPayload = 'prayer';

  /// Called with the payload when the user taps one of our notifications
  /// while the app is running. Cold starts go through [launchPayload].
  static void Function(String? payload)? onTap;

  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // unknown zone id: falls back to UTC, reminder may drift by the offset
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        if (r.actionId == stopAdhanAction) return; // just silence it
        onTap?.call(r.payload);
      },
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundResponse,
    );
    _ready = true;
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Payload of the notification that cold-started the app, if any.
  static Future<String?> launchPayload() async {
    await init();
    final d = await _plugin.getNotificationAppLaunchDetails();
    if (d == null || !d.didNotificationLaunchApp) return null;
    return d.notificationResponse?.payload;
  }

  /// Android 12+: whether "Alarms & reminders" is allowed (denied by
  /// default for new installs on 14+). Other platforms: always true.
  static Future<bool> canScheduleExact() async {
    await init();
    return await _android?.canScheduleExactNotifications() ?? true;
  }

  /// Opens the system "Alarms & reminders" page for this app.
  static Future<void> requestExactAlarms() async {
    await init();
    await _android?.requestExactAlarmsPermission();
  }

  static AndroidScheduleMode scheduleModeFor({required bool exact}) => exact
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  static const stopAdhanAction = 'stop_adhan';

  static NotificationDetails _prayerDetails(PrayerChannel c) => switch (c) {
        PrayerChannel.adhan => const NotificationDetails(
            android: AndroidNotificationDetails(
              adhanChannelId,
              'الأذان',
              channelDescription: 'تنبيه عند دخول وقت كل صلاة',
              importance: Importance.max,
              priority: Priority.high,
              category: AndroidNotificationCategory.reminder,
              visibility: NotificationVisibility.public,
              // dismissing the notification stops its sound; this does it
              // without opening the app
              actions: [
                AndroidNotificationAction(stopAdhanAction, 'إيقاف الأذان',
                    cancelNotification: true),
              ],
            ),
            iOS: DarwinNotificationDetails(),
          ),
        PrayerChannel.notify => const NotificationDetails(
            android: AndroidNotificationDetails(
              'prayer_notify_v1',
              'وقت الصلاة (إشعار)',
              channelDescription: 'إشعار بنغمة عادية للصلوات المضبوطة على «إشعار»',
              importance: Importance.high,
              priority: Priority.high,
              category: AndroidNotificationCategory.reminder,
              visibility: NotificationVisibility.public,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        PrayerChannel.reminder => const NotificationDetails(
            android: AndroidNotificationDetails(
              'prayer_reminder_v1',
              'تذكير قبل الصلاة',
              channelDescription: 'تذكير قبل دخول وقت الصلاة بدقائق',
              importance: Importance.defaultImportance,
              category: AndroidNotificationCategory.reminder,
              visibility: NotificationVisibility.public,
            ),
            iOS: DarwinNotificationDetails(),
          ),
      };

  /// One prayer notification at [at]; tapping opens the prayer screen.
  /// Falls back to inexact if the exact permission was revoked between the
  /// check and this call.
  static Future<void> scheduleAdhan({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required bool exact,
    PrayerChannel channel = PrayerChannel.adhan,
  }) async {
    await init();
    final when = tz.TZDateTime.from(at, tz.local);
    if (!when.isAfter(tz.TZDateTime.now(tz.local))) return;
    final details = _prayerDetails(channel);
    Future<void> go(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id: id,
          scheduledDate: when,
          title: title,
          body: body,
          notificationDetails: details,
          androidScheduleMode: mode,
          payload: prayerPayload,
        );
    try {
      await go(scheduleModeFor(exact: exact));
    } on PlatformException {
      if (!exact) rethrow;
      await go(scheduleModeFor(exact: false));
    }
  }

  /// Cancels only notifications still waiting in [from]..[to]. A shown
  /// notification is left alone, so a replan never cuts an adhan short.
  static Future<void> cancelPendingInRange(int from, int to) async {
    await init();
    for (final r in await _plugin.pendingNotificationRequests()) {
      if (r.id >= from && r.id <= to) await _plugin.cancel(id: r.id);
    }
  }

  static Future<bool> requestPermission() async {
    await init();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final ok = await ios?.requestPermissions(alert: true, sound: true) ??
        await android?.requestNotificationsPermission() ??
        false;
    return ok;
  }

  static Future<void> scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: at,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminders',
          'تذكيرات يومية',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// One-shot notification at [at] (local time); skipped if in the past.
  static Future<void> scheduleAt({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    await init();
    final when = tz.TZDateTime.from(at, tz.local);
    if (!when.isAfter(tz.TZDateTime.now(tz.local))) return;
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: when,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_ayah',
          'آية اليوم',
          importance: Importance.defaultImportance,
          styleInformation: BigTextStyleInformation(''),
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static Future<void> cancel(int id) async {
    await init();
    await _plugin.cancel(id: id);
  }
}
