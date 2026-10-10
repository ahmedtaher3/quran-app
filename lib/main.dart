import 'package:flutter/material.dart';

import 'loading_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
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
