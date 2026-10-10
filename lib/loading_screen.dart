import 'dart:async';
import 'package:flutter/material.dart';
import 'package:untitled/features/Koran/data/data_sources/import_isolate.dart';
import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';
import 'package:untitled/features/Koran/data/model/ayah.dart';
import 'package:untitled/features/Koran/presentation/view/sura_view.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  double progress = 0;
  Verse? randomVerse;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // 1. Fetch random verse
    final verse = await DBHelper.getRandomVerse();
    if (mounted) {
      setState(() {
        randomVerse = verse;
      });
      _animationController.forward();
    }

    // 2. Start import/check if empty
    final startTime = DateTime.now();
    final isEmpty = await DBHelper.isDatabaseEmpty();

    if (isEmpty) {
      setState(() => _isImporting = true);
      final db = await DBHelper.database;
      await ImportIsolate.process(db, (double p) {
        if (mounted) setState(() => progress = p);
      });
    }

    // 3. Ensure minimum display time of 4 seconds to read the Ayah
    final elapsed = DateTime.now().difference(startTime);
    if (elapsed < const Duration(seconds: 5)) {
      await Future.delayed(const Duration(seconds: 5) - elapsed);
    }

    _goToHome();
  }

  void _goToHome() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => SuraView(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: Duration(milliseconds: 1000),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background with Animated Gradient look (using custom colors)
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF004D40), // Dark Teal
                  const Color(0xFF00695C), // Medium Teal
                  const Color(0xFF00897B), // Light Teal
                ],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Top Logo Area
                  ScaleTransition(
                    scale: _fadeAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.white.withOpacity(0.15)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_stories_rounded,
                        color: Colors.white,
                        size: 45,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Random Ayah Section - Scrollable to prevent overflow
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            if (randomVerse != null) ...[
                              Text(
                                randomVerse!.text,
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(
                                  fontSize: 26,
                                  
                                  color: Colors.white,
                                  height: 1.6,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black38,
                                      offset: Offset(0, 2),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 25),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.07),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.1)),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      randomVerse!.tafsir ?? "",
                                      textAlign: TextAlign.center,
                                      textDirection: TextDirection.rtl,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white.withOpacity(0.95),
                                        height: 1.6,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 15),
                                    Container(
                                      height: 1,
                                      width: 50,
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      "${randomVerse!.suraName ?? 'سورة ${randomVerse!.sura}'} - آية ${randomVerse!.ayaNumber}",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white.withOpacity(0.5),
                                        fontWeight: FontWeight.w300,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              const Text(
                                "وَقُلْ رَبِّ زِدْنِي عِلْمًا",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 32,
                                  
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black26,
                                      offset: Offset(0, 2),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom Loading Section
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Column(
                      children: [
                        if (_isImporting) ...[
                          Container(
                            width: double.infinity,
                            height: 6,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.white.withOpacity(0.1),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            "جاري تهيئة المصحف الشريف... ${(progress * 100).toStringAsFixed(0)}%",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white70),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          "يتم التحميل الآن",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
