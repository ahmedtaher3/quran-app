import 'dart:io';

import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:untitled/core/app_theme.dart';
import 'package:untitled/core/notifications.dart';
import 'package:untitled/features/prayer/adhan_scheduler.dart';
import 'package:untitled/features/prayer/adhan_prefs.dart';
import 'package:untitled/features/prayer/hijri_date.dart';
import 'package:untitled/features/prayer/prayer_controller.dart';
import 'package:untitled/features/prayer/prayer_service.dart';
import 'package:untitled/features/prayer/widget_sync.dart';
import 'package:untitled/features/prayer/widgets/location_intro.dart';
import 'package:untitled/features/prayer/widgets/prayer_alert_sheet.dart';
import 'package:untitled/features/prayer/widgets/adhan_sound_view.dart';
import 'package:untitled/features/prayer/widgets/settings_group.dart';
import 'package:untitled/features/prayer/adhan_sound/adhan_sound_store.dart';

/// Everything that used to sit under the prayer list, in its own screen.
class PrayerSettingsView extends StatelessWidget {
  final PrayerController controller;
  const PrayerSettingsView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final s = c.settings!;
        final primary = Theme.of(context).colorScheme.primary;
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            title: const Text('إعدادات الصلاة'),
            backgroundColor: AppColors.bg,
            foregroundColor: AppColors.text,
            surfaceTintColor: Colors.transparent,
          ),
          body: ListView(
            padding: EdgeInsets.fromLTRB(
                16, 0, 16, 24 + MediaQuery.paddingOf(context).bottom),
            children: [
              const SettingsTitle('التنبيهات'),
              SettingsGroup(children: [
                SwitchListTile(
                  value: s.notify,
                  onChanged: (v) => c.update(
                      PrayerSettings(s.lat, s.lng, s.method, s.madhab, v)),
                  title: const Text('تنبيه عند دخول وقت الصلاة'),
                  subtitle: const Text('الصلوات الخمس، والشروق بدون تنبيه'),
                  secondary: Icon(Icons.notifications_active_rounded, color: primary),
                ),
                if (s.notify)
                  ListTile(
                    leading: Icon(Icons.play_circle_outline_rounded, color: primary),
                    title: const Text('جرّب الأذان'),
                    subtitle: const Text('يصلك تنبيه تجريبي خلال ثوانٍ'),
                    onTap: () async {
                      await AdhanScheduler.scheduleTest();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('سيصلك أذان تجريبي خلال ثوانٍ')));
                    },
                  ),
                if (s.notify)
                  c.exactOk
                      ? ListTile(
                          leading: Icon(Icons.verified_rounded, color: primary),
                          title: const Text('المنبهات الدقيقة مفعّلة'),
                          subtitle: const Text('الأذان يصل في وقته بالضبط'),
                        )
                      : ListTile(
                          leading: const Icon(Icons.alarm_rounded, color: Color(0xFFB26A00)),
                          title: const Text('المنبهات الدقيقة غير مفعّلة'),
                          subtitle: const Text('قد يتأخر الأذان. اضغط للتفعيل'),
                          trailing: const Icon(Icons.chevron_left_rounded),
                          onTap: Notifications.requestExactAlarms,
                        ),
              ]),
              if (s.notify) ...[
                const SettingsTitle('تنبيه كل صلاة'),
                SettingsGroup(children: [
                  for (final p in fivePrayers)
                    ListTile(
                      leading: Icon(
                          c.alertFor(p).mode == AlertMode.off
                              ? Icons.notifications_off_outlined
                              : Icons.notifications_active_rounded,
                          color: c.alertFor(p).mode == AlertMode.off
                              ? AppColors.subtle
                              : primary),
                      title: Text(prayerNames[p]!),
                      subtitle: Text(c.alertFor(p).summary),
                      trailing: const Icon(Icons.chevron_left_rounded),
                      onTap: () => showPrayerAlertSheet(context, c, p),
                    ),
                ]),
                // The sound picker is Android-only (AdhanSoundChannel.kt);
                // iOS has no native side for it yet.
                if (Platform.isAndroid) ...[
                  const SettingsTitle('صوت الأذان'),
                  const _AdhanSoundRows(),
                ],
              ],
              const SettingsTitle('الحساب'),
              SettingsGroup(children: [
                ListTile(
                  leading: Icon(Icons.calculate_rounded, color: primary),
                  title: const Text('طريقة الحساب'),
                  subtitle: Text(methodNames[s.method] ?? s.method.name),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () async {
                    final m = await _pickMethod(context, s.method);
                    if (m != null && m != s.method) {
                      c.update(PrayerSettings(s.lat, s.lng, m, s.madhab, s.notify));
                    }
                  },
                ),
                ListTile(
                  leading: Icon(Icons.wb_sunny_outlined, color: primary),
                  title: const Text('وقت العصر'),
                  subtitle: Text(s.madhab == Madhab.hanafi
                      ? 'الحنفي (ظل المثلين)'
                      : 'الجمهور (ظل المثل)'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<Madhab>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: Madhab.shafi, label: Text('الجمهور')),
                        ButtonSegment(value: Madhab.hanafi, label: Text('الحنفي')),
                      ],
                      selected: {s.madhab},
                      onSelectionChanged: (v) => c.update(
                          PrayerSettings(s.lat, s.lng, s.method, v.first, s.notify)),
                    ),
                  ),
                ),
              ]),
              const SettingsTitle('التاريخ الهجري'),
              SettingsGroup(children: [
                ListTile(
                  leading: Icon(Icons.calendar_month_rounded, color: primary),
                  title: Text(HijriDate.format(DateTime.now(), adjust: c.hijriAdjust)),
                  subtitle: const Text('عدّل يومًا أو يومين حسب رؤية الهلال في بلدك'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'يوم أقل',
                        onPressed: c.hijriAdjust > -HijriDate.maxAdjust
                            ? () => c.setHijriAdjust(c.hijriAdjust - 1)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                      ),
                      Text(c.hijriAdjust > 0 ? '+${c.hijriAdjust}' : '${c.hijriAdjust}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text)),
                      IconButton(
                        tooltip: 'يوم زيادة',
                        onPressed: c.hijriAdjust < HijriDate.maxAdjust
                            ? () => c.setHijriAdjust(c.hijriAdjust + 1)
                            : null,
                        icon: const Icon(Icons.add_circle_outline_rounded),
                      ),
                    ],
                  ),
                ),
              ]),
              FutureBuilder<bool>(
                future: WidgetSync.canPin(),
                builder: (context, snap) => snap.data != true
                    ? const SizedBox.shrink()
                    : Column(children: [
                        const SettingsTitle('الشاشة الرئيسية'),
                        SettingsGroup(children: [
                          ListTile(
                            leading: Icon(Icons.widgets_outlined, color: primary),
                            title: const Text('أضف ويدجت المواقيت'),
                            subtitle: const Text('الصلاة القادمة وعدّ تنازلي على الشاشة الرئيسية'),
                            trailing: const Icon(Icons.add_rounded),
                            onTap: WidgetSync.pin,
                          ),
                        ]),
                      ]),
              ),
              const SettingsTitle('الموقع'),
              SettingsGroup(children: [
                ListTile(
                  leading: Icon(Icons.location_on_rounded, color: primary),
                  title: Text(c.place ?? 'موقعك الحالي'),
                  subtitle: Text(
                      '${s.lat.toStringAsFixed(3)}، ${s.lng.toStringAsFixed(3)}'),
                ),
                ListTile(
                  leading: Icon(Icons.my_location_rounded, color: primary),
                  title: const Text('تحديث من موقعي الحالي'),
                  trailing: c.locating
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : null,
                  onTap: c.locating ? null : c.locate,
                ),
                ListTile(
                  leading: Icon(Icons.location_city_rounded, color: primary),
                  title: const Text('اختيار المدينة يدويًا'),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () async {
                    final city = await pickCity(context);
                    if (city != null) c.useCity(city);
                  },
                ),
                if (c.error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(c.error!, style: const TextStyle(color: Color(0xFFB26A00))),
                  ),
              ]),
            ],
          ),
        );
      },
    );
  }

  Future<CalculationMethod?> _pickMethod(BuildContext context, CalculationMethod current) {
    return showModalBottomSheet<CalculationMethod>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final e in methodNames.entries)
              ListTile(
                title: Text(e.value, style: TextStyle(color: AppColors.text)),
                trailing: e.key == current
                    ? Icon(Icons.check_rounded, color: Theme.of(ctx).colorScheme.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, e.key),
              ),
          ],
        ),
      ),
    );
  }
}

/// "صوت الأذان" and "أذان الفجر", each showing the current choice and
/// opening the picker on its tab.
class _AdhanSoundRows extends StatefulWidget {
  const _AdhanSoundRows();

  @override
  State<_AdhanSoundRows> createState() => _AdhanSoundRowsState();
}

class _AdhanSoundRowsState extends State<_AdhanSoundRows> {
  final store = AdhanSoundStore.instance;

  @override
  void initState() {
    super.initState();
    store.load();
  }

  void _open(bool fajr) => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AdhanSoundView(startFajr: fajr)));

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => SettingsGroup(children: [
        ListTile(
          leading: Icon(Icons.music_note_rounded, color: primary),
          title: const Text('صوت الأذان'),
          subtitle: Text(store.sounds.labelFor(fajr: false),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_left_rounded),
          onTap: () => _open(false),
        ),
        ListTile(
          leading: Icon(Icons.nightlight_round, color: primary),
          title: const Text('أذان الفجر'),
          subtitle: Text(store.sounds.labelFor(fajr: true),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_left_rounded),
          onTap: () => _open(true),
        ),
      ]),
    );
  }
}
