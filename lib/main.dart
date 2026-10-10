import 'package:flutter/material.dart';

import 'package:just_audio_background/just_audio_background.dart';
import 'package:untitled/features/audio/quran_player.dart';
import 'package:untitled/features/audio/audio_downloads.dart';
import 'package:untitled/features/daily/daily_ayah.dart';
import 'loading_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.tarik.al.quran.audio',
    androidNotificationChannelName: 'تلاوة القرآن',
    androidNotificationOngoing: true,
  );
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      title: 'Tarik Al Quran',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00695C), // Deep Teal/Emerald
          primary: const Color(0xFF00695C),
          secondary: const Color(0xFFFFB300), // Amber/Gold
        ),
        useMaterial3: true,
        fontFamily: 'Nabi',
        scaffoldBackgroundColor:
            const Color(0xFFF9FBF9), // Soft White/Mint background
      ),
      home: LoadingScreen(),
    );
  }
}
