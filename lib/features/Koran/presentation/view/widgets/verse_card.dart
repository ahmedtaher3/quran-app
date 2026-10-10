import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';
import 'package:untitled/features/Koran/data/model/ayah.dart';
import 'package:untitled/features/Koran/presentation/manager/cubit/verse_cubit.dart';
import 'package:untitled/features/Koran/presentation/view/widgets/audio_player_sheet.dart';
import 'package:untitled/words_dialog.dart';
import 'package:untitled/core/constants/app_constants.dart';

class VerseCard extends StatelessWidget {
  final Verse verse;
  final bool highlight; // <<< الجديد

  const VerseCard({
    super.key,
    required this.verse,
    this.highlight = false,
  });

  bool isBasmala(String text) {
    final normalized = text
        .replaceAll("ٱ", "ا")
        .replaceAll("ٰ", "")
        .replaceAll("ـ", "")
        .replaceAll("ً", "")
        .replaceAll("ٌ", "")
        .replaceAll("ٍ", "")
        .replaceAll("َ", "")
        .replaceAll("ُ", "")
        .replaceAll("ِ", "")
        .replaceAll("ّ", "")
        .replaceAll("ْ", "")
        .trim();

    return normalized == "بسم الله الرحمن الرحيم";
  }

  @override
  Widget build(BuildContext context) {
    if (isBasmala(verse.text)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            children: [
              Container(
                width: 100,
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.teal.shade300,
                      Colors.transparent
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                verse.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  
                  fontSize: 32,
                  height: 1.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade800,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 100,
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.teal.shade300,
                      Colors.transparent
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFF1F8E9) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: highlight ? Colors.teal.shade200 : Colors.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: highlight
                ? Colors.teal.withOpacity(0.1)
                : Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              children: [
                // Arabic Text
                Text(
                  verse.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    
                    fontSize: 26,
                    height: 2.0,
                    color: Colors.black.withOpacity(0.85),
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 24),
                // Aya Number Ornament
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.star_outline_rounded,
                      size: 40,
                      color: Colors.teal.shade100,
                    ),
                    Text(
                      verse.ayaNumber?.toString() ?? "",
                      style: TextStyle(
                        
                        fontSize: 14,
                        color: Colors.teal.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.teal.shade50.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionButton(
                  icon: Icons.language_rounded,
                  color: Colors.blue.shade700,
                  onTap: () async {
                    final words = await DBHelper.getWordsByAyah(verse.id);
                    showDialog(
                      context: context,
                      builder: (_) => WordsDialog(words: words),
                    );
                  },
                ),
                _ActionButton(
                  icon: Icons.auto_stories_rounded,
                  color: Colors.orange.shade800,
                  onTap: () => _showTafsir(context),
                ),
                _ActionButton(
                  icon: Icons.bookmark_rounded,
                  color: highlight ? Colors.teal : Colors.grey.shade400,
                  onTap: () async {
                    int suraNumber = verse.sura;
                    await context
                        .read<VerseCubit>()
                        .saveLastViewedAyah(suraNumber, verse.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("تم حفظ موضع القراءة"),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Color(0xFF00695C),
                      ),
                    );
                  },
                ),
                IconButton.filled(
                  icon: const Icon(Icons.play_arrow_rounded),
                  onPressed: () {
                    final url =
                        "${AppConstants.verseAudioBaseUrl}${verse.audio}";
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (sheetContext) => AudioPlayerSheet(
                        audioUrl: url,
                        suraName: verse.text ?? '',
                        ayaNumber: verse.ayaNumber,
                        onPlaySequential: () {
                          // Using context from VerseCard to access VerseCubit
                          context
                              .read<VerseCubit>()
                              .playSequentiallyFrom(verse.id);
                        },
                      ),
                    );
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF00695C),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(48, 48),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTafsir(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  " الآية",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00695C),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  verse.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    
                    fontSize: 26,
                    height: 2.0,
                    color: Colors.black87,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const Text(
                  "تفسير الآية",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00695C),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      verse.tafsir ?? "لا يوجد تفسير متاح حالياً",
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.8,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00695C),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text("إغلاق",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}
