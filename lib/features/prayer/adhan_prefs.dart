import 'package:adhan/adhan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled/features/prayer/prayer_service.dart';

enum AlertMode {
  adhan('أذان'),
  notify('إشعار'),
  off('إيقاف');

  final String label;
  const AlertMode(this.label);
}

/// How one prayer alerts: adhan, a plain notification or nothing, plus an
/// optional reminder some minutes before.
class PrayerAlert {
  final AlertMode mode;
  final int reminderMinutes; // 0 = no reminder
  const PrayerAlert({this.mode = AlertMode.adhan, this.reminderMinutes = 0});

  PrayerAlert copyWith({AlertMode? mode, int? reminderMinutes}) => PrayerAlert(
        mode: mode ?? this.mode,
        reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      );

  String get summary {
    final r = reminderMinutes > 0 ? ' · تذكير قبلها بـ $reminderMinutes د' : '';
    return '${mode.label}$r';
  }

  @override
  bool operator ==(Object other) =>
      other is PrayerAlert &&
      other.mode == mode &&
      other.reminderMinutes == reminderMinutes;

  @override
  int get hashCode => Object.hash(mode, reminderMinutes);
}

/// Per-prayer alert settings, stored under their own keys so the existing
/// prayer settings are untouched. Missing keys mean "adhan, no reminder",
/// which is how the app behaved before.
class AdhanPrefs {
  static const reminderOptions = [0, 5, 10, 15, 20, 30];

  static String _key(Prayer p, String field) => 'prayer_alert_${p.name}_$field';

  static Future<Map<Prayer, PrayerAlert>> load() async {
    final sp = await SharedPreferences.getInstance();
    return {
      for (final p in fivePrayers)
        p: PrayerAlert(
          mode: AlertMode.values.asNameMap()[sp.getString(_key(p, 'mode'))] ??
              AlertMode.adhan,
          reminderMinutes: sp.getInt(_key(p, 'pre')) ?? 0,
        ),
    };
  }

  static Future<void> save(Prayer p, PrayerAlert a) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key(p, 'mode'), a.mode.name);
    await sp.setInt(_key(p, 'pre'), a.reminderMinutes);
  }
}
