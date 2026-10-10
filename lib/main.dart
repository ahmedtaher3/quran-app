import 'package:flutter/material.dart';

import 'package:just_audio_background/just_audio_background.dart';
import 'package:untitled/features/audio/quran_player.dart';
import 'package:untitled/features/audio/audio_downloads.dart';
import 'package:untitled/features/daily/daily_ayah.dart';
import 'package:untitled/core/app_theme.dart';
import 'loading_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.tarik.al.quran.audio',
    androidNotificationChannelName: 'تلاوة القرآن',
    androidNotificationOngoing: true,
  );
  await AppSettings.instance.load();
  await QuranPlayer.instance.loadPrefs();
  await AudioDownloads.instance.init();
  QuranPlayer.instance.startLogging();
  runApp(const MyApp());
  DailyAyahPrefs.reschedule(); // keeps the next 7 days planned
}
//  Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (_) => const SearchScreen()),
//               );

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => AppSettings.instance.platformChanged();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final settings = AppSettings.instance;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          title: 'Tarik Al Quran',
          theme: settings.themeData,
          home: const LoadingScreen(),
        );
      },
    );
  }
}
