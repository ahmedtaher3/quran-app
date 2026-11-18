import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:untitled/core/app_theme.dart';
import 'package:untitled/core/notifications.dart';
import 'package:untitled/features/prayer/hijri_date.dart';
import 'package:untitled/features/prayer/prayer_controller.dart';
import 'package:untitled/features/prayer/prayer_service.dart';
import 'package:untitled/features/prayer/widgets/location_intro.dart';
import 'package:untitled/features/prayer/widgets/prayer_hero_card.dart';
import 'package:untitled/features/prayer/widgets/prayer_settings_view.dart';
import 'package:untitled/features/prayer/widgets/prayer_times_list.dart';
import 'package:untitled/features/prayer/widgets/qibla_compass.dart';

class PrayerView extends StatefulWidget {
  const PrayerView({super.key});

  /// The route of the prayer screen currently in the stack, however it was
  /// opened, so a notification tap brings it forward instead of stacking a
  /// second one.
  static Route<dynamic>? get openRoute => _openRoute;
  static Route<dynamic>? _openRoute;

  @override
  State<PrayerView> createState() => _PrayerViewState();
}

class _PrayerViewState extends State<PrayerView> {
  final _c = PrayerController();
  Route<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    _c.init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    PrayerView._openRoute = _route;
  }

  @override
  void dispose() {
    if (PrayerView._openRoute == _route) PrayerView._openRoute = null;
    _c.dispose();
    super.dispose();
  }

  void _openSettings() => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PrayerSettingsView(controller: _c)));

  Future<void> _pickCity() async {
    final city = await pickCity(context);
    if (city != null) _c.useCity(city);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final s = _c.settings;
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: AppColors.bg,
            appBar: AppBar(
              backgroundColor: AppColors.bg,
              foregroundColor: AppColors.text,
              surfaceTintColor: Colors.transparent,
              titleSpacing: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('مواقيت الصلاة',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                  if (s != null)
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: AppColors.subtle),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(_c.place ?? 'موقعك الحالي',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, color: AppColors.subtle)),
                        ),
                      ],
                    ),
                ],
              ),
              actions: [
                if (s != null)
                  IconButton(
                    tooltip: 'تحديث الموقع',
                    onPressed: _c.locating ? null : _c.locate,
                    icon: _c.locating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location_rounded),
                  ),
                if (s != null)
                  IconButton(
                    tooltip: 'إعدادات الصلاة',
                    onPressed: _openSettings,
                    icon: const Icon(Icons.tune_rounded),
                  ),
              ],
            ),
            body: !_c.loaded
                ? const Center(child: CircularProgressIndicator())
                : s == null
                    ? LocationIntro(
                        locating: _c.locating,
                        error: _c.error,
                        onUseLocation: _c.locate,
                        onPickCity: _pickCity,
                      )
                    : _body(s),
          ),
        );
      },
    );
  }

  Widget _body(PrayerSettings s) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ListenableBuilder(
      listenable: _c.clock!, // prayer boundaries and midnight
      builder: (context, _) {
        final now = DateTime.now();
        return Column(
          children: [
            _DateLine(now: now, hijriAdjust: _c.hijriAdjust),
            const _Segments(),
            Expanded(
              child: TabBarView(
                children: [
                  ListView(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + bottom),
                    children: [
                      if (_c.moved)
                        _Banner(
                          icon: Icons.travel_explore_rounded,
                          title: 'يبدو أنك في مكان آخر',
                          body: 'حدّث الموقع لتصبح المواقيت واتجاه القبلة صحيحة هنا.',
                          action: 'تحديث',
                          onAction: _c.locate,
                          onClose: _c.dismissMoved,
                        ),
                      if (s.notify && !_c.exactOk)
                        const _Banner(
                          icon: Icons.alarm_rounded,
                          title: 'قد يتأخر الأذان بضع دقائق',
                          body: 'اسمح بـ«المنبهات والتذكيرات» ليُرفع الأذان في وقته بالضبط.',
                          action: 'تفعيل',
                          onAction: Notifications.requestExactAlarms,
                        ),
                      PrayerHeroCard(settings: s, onAlertTap: _openSettings),
                      const SizedBox(height: 12),
                      PrayerTimesList(settings: s, now: now),
                      const SizedBox(height: 12),
                      _Footer(settings: s, onTap: _openSettings),
                    ],
                  ),
                  QiblaCompass(settings: s, declination: _c.declination),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DateLine extends StatelessWidget {
  final DateTime now;
  final int hijriAdjust;
  const _DateLine({required this.now, required this.hijriAdjust});

  @override
  Widget build(BuildContext context) {
    final greg = MaterialLocalizations.of(context).formatFullDate(now);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        runSpacing: 2,
        children: [
          Text(HijriDate.format(now, adjust: hijriAdjust),
              style: TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.text)),
          Text(greg, style: TextStyle(fontSize: 13, color: AppColors.subtle)),
        ],
      ),
    );
  }
}

/// Pill-shaped tab switch (replaces the old teal TabBar).
class _Segments extends StatelessWidget {
  const _Segments();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: AppColors.tealSoft, borderRadius: BorderRadius.circular(99)),
      child: TabBar(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        splashBorderRadius: BorderRadius.circular(99),
        indicator: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(99),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 1))],
        ),
        labelColor: AppColors.text,
        unselectedLabelColor: AppColors.subtle,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
        unselectedLabelStyle: const TextStyle(fontSize: 14.5),
        tabs: const [
          Tab(height: 40, child: _TabLabel(Icons.schedule_rounded, 'المواقيت')),
          Tab(height: 40, child: _TabLabel(Icons.explore_rounded, 'القبلة')),
        ],
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TabLabel(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 18), const SizedBox(width: 6), Text(text)],
      );
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String title, body, action;
  final VoidCallback onAction;
  final VoidCallback? onClose;
  const _Banner({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 6, 10),
      decoration: BoxDecoration(
          color: AppColors.amberSoft, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFB26A00)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text)),
                Text(body, style: TextStyle(fontSize: 12.5, color: AppColors.subtle)),
              ],
            ),
          ),
          TextButton(onPressed: onAction, child: Text(action)),
          if (onClose != null)
            IconButton(
              tooltip: 'إخفاء',
              visualDensity: VisualDensity.compact,
              onPressed: onClose,
              icon: Icon(Icons.close_rounded, size: 18, color: AppColors.subtle),
            ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final PrayerSettings settings;
  final VoidCallback onTap;
  const _Footer({required this.settings, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final asr = settings.madhab == Madhab.hanafi ? 'العصر الحنفي' : 'العصر الجمهور';
    return Center(
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(Icons.calculate_outlined, size: 16, color: AppColors.subtle),
        label: Text('${methodNames[settings.method]} · $asr',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.subtle)),
      ),
    );
  }
}
