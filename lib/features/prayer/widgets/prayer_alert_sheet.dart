import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:untitled/core/app_theme.dart';
import 'package:untitled/features/prayer/adhan_prefs.dart';
import 'package:untitled/features/prayer/prayer_controller.dart';
import 'package:untitled/features/prayer/prayer_service.dart';

/// Alert settings for one prayer: adhan / notification / off, and an
/// optional reminder before it. Saving replans the alarms.
Future<void> showPrayerAlertSheet(
    BuildContext context, PrayerController c, Prayer prayer) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (_) => _AlertSheet(controller: c, prayer: prayer),
  );
}

class _AlertSheet extends StatefulWidget {
  final PrayerController controller;
  final Prayer prayer;
  const _AlertSheet({required this.controller, required this.prayer});

  @override
  State<_AlertSheet> createState() => _AlertSheetState();
}

class _AlertSheetState extends State<_AlertSheet> {
  late PrayerAlert _a = widget.controller.alertFor(widget.prayer);

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final allOff = !(c.settings?.notify ?? false);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تنبيه صلاة ${prayerNames[widget.prayer]}',
                style: TextStyle(
                    fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.text)),
            if (allOff) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppColors.amberSoft, borderRadius: BorderRadius.circular(12)),
                child: Text('التنبيه العام متوقف. فعّله من الإعدادات ليعمل هذا الاختيار.',
                    style: TextStyle(fontSize: 13, color: AppColors.text)),
              ),
            ],
            const SizedBox(height: 16),
            Text('نوع التنبيه', style: TextStyle(fontSize: 13, color: AppColors.subtle)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<AlertMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: AlertMode.adhan,
                      icon: Icon(Icons.notifications_active_rounded),
                      label: Text('أذان')),
                  ButtonSegment(
                      value: AlertMode.notify,
                      icon: Icon(Icons.notifications_none_rounded),
                      label: Text('إشعار')),
                  ButtonSegment(
                      value: AlertMode.off,
                      icon: Icon(Icons.notifications_off_outlined),
                      label: Text('إيقاف')),
                ],
                selected: {_a.mode},
                onSelectionChanged: (v) => setState(() => _a = _a.copyWith(mode: v.first)),
              ),
            ),
            const SizedBox(height: 18),
            Text('تذكير قبل الصلاة', style: TextStyle(fontSize: 13, color: AppColors.subtle)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in AdhanPrefs.reminderOptions)
                  ChoiceChip(
                    label: Text(m == 0 ? 'بدون' : '$m د'),
                    selected: _a.reminderMinutes == m,
                    onSelected: (_) =>
                        setState(() => _a = _a.copyWith(reminderMinutes: m)),
                  ),
              ],
            ),
            if (_a.mode == AlertMode.off && _a.reminderMinutes > 0) ...[
              const SizedBox(height: 10),
              Text('سيصلك التذكير فقط، دون تنبيه عند دخول الوقت.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.subtle)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  c.setAlert(widget.prayer, _a);
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('حفظ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
