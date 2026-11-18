import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:untitled/core/app_theme.dart';
import 'package:untitled/features/prayer/cities.dart';
import 'package:untitled/features/prayer/hijri_date.dart';
import 'package:untitled/features/prayer/prayer_controller.dart';
import 'package:untitled/features/prayer/prayer_service.dart';
import 'package:untitled/features/prayer/widgets/prayer_hero_card.dart';
import 'package:untitled/features/prayer/widgets/prayer_times_list.dart';
import 'package:untitled/features/prayer/widgets/qibla_compass.dart';
import 'package:untitled/features/prayer/widgets/time_format.dart';

// Cairo
const s = PrayerSettings(
    30.0444, 31.2357, CalculationMethod.egyptian, Madhab.shafi, true);

Widget _host(Widget child, {double textScale = 1}) => MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppSettings.instance.themeData,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: app!,
      ),
      home: Scaffold(
        backgroundColor: AppColors.bg,
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(16), child: child),
      ),
    );

void main() {
  group('times list', () {
    final t = s.timesFor(DateTime(2026, 3, 1));

    testWidgets('between fajr and sunrise, dhuhr is marked next', (tester) async {
      await tester.pumpWidget(_host(PrayerTimesList(
          settings: s, now: t.fajr.add(const Duration(minutes: 5)))));
      expect(find.text('القادمة'), findsOneWidget);
      expect(find.text('للعلم، ليس وقت صلاة'), findsOneWidget);
      // the "next" chip sits in the dhuhr row
      final row = find.ancestor(of: find.text('الظهر'), matching: find.byType(Row)).first;
      expect(find.descendant(of: row, matching: find.text('القادمة')), findsOneWidget);
    });

    testWidgets('after isha, tomorrow\'s fajr is marked', (tester) async {
      await tester.pumpWidget(_host(PrayerTimesList(
          settings: s, now: t.isha.add(const Duration(minutes: 5)))));
      expect(find.text('غدًا'), findsOneWidget);
    });
  });

  // every theme, at a narrow width and large text, without overflow
  for (final theme in [ThemeChoice.light, ThemeChoice.dark, ThemeChoice.sepia]) {
    testWidgets('hero + list fit at 360dp, text x1.3, ${theme.name}', (tester) async {
      AppSettings.instance.theme = theme;
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(
        Column(children: [
          const PrayerHeroCard(settings: s),
          const SizedBox(height: 12),
          PrayerTimesList(settings: s, now: DateTime(2026, 3, 1, 13)),
        ]),
        textScale: 1.3,
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('الصلاة القادمة'), findsOneWidget);
      await tester.pumpWidget(const SizedBox()); // stop the 1s ticker
    });
  }

  testWidgets('prayer time keeps h:mm together, 12h and 24h', (tester) async {
    late String t12, t24;
    await tester.pumpWidget(_host(Builder(builder: (context) {
      t12 = prayerTime(context, DateTime(2026, 3, 1, 16, 58));
      return const SizedBox();
    })));
    expect(t12, contains('4:58'));
    expect(t12, endsWith('م'));
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(alwaysUse24HourFormat: true),
      child: Builder(builder: (context) {
        t24 = prayerTime(context, DateTime(2026, 3, 1, 4, 5));
        return const SizedBox();
      }),
    ));
    expect(t24, contains('04:05'));
  });

  test('countdown format', () {
    expect(formatCountdown(const Duration(hours: 1, minutes: 2, seconds: 3)), '01:02:03');
    expect(formatCountdown(const Duration(seconds: -5)), '00:00:00');
  });

  test('turn direction to the qibla', () {
    expect(turnTo(136, 100), closeTo(36, 1e-9)); // turn right
    expect(turnTo(136, 170), closeTo(-34, 1e-9)); // turn left
    expect(turnTo(10, 350), closeTo(20, 1e-9)); // across north
  });

  group('hijri date', () {
    test('Arabic Umm al-Qura text', () {
      final txt = HijriDate.format(DateTime(2026, 11, 18));
      expect(txt, contains('جمادى'));
      expect(txt, endsWith('هـ'));
    });

    test('adjustment moves the day', () {
      final a = HijriDate.format(DateTime(2026, 11, 18));
      final b = HijriDate.format(DateTime(2026, 11, 18), adjust: 1);
      expect(a, isNot(b));
      expect(b, HijriDate.format(DateTime(2026, 11, 19)));
    });
  });

  group('places', () {
    test('a point in Cairo is named Cairo', () {
      expect(nearestCity(30.06, 31.25)?.name, 'القاهرة');
    });

    test('a point far from every listed city has no name', () {
      expect(nearestCity(0, -140), isNull);
    });

    test('travel is suggested beyond 25 km only', () {
      expect(isFarFrom(s, 30.10, 31.30), isFalse); // ~9 km
      expect(isFarFrom(s, 31.20, 29.92), isTrue); // Alexandria
    });
  });
}
