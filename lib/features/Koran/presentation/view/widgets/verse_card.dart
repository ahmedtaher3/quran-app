import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';
import 'package:untitled/features/Koran/data/model/ayah.dart';
import 'package:untitled/features/Koran/data/model/bookmark.dart';
import 'package:untitled/features/Koran/presentation/view/widgets/bookmark_sheet.dart';
import 'package:untitled/features/Koran/presentation/manager/cubit/verse_cubit.dart';
import 'package:untitled/features/Koran/presentation/view/widgets/audio_player_sheet.dart';
import 'package:untitled/words_dialog.dart';
import 'package:untitled/features/tafsir/tafsir_sheet.dart';
import 'package:untitled/features/audio/quran_player.dart';

class VerseCard extends StatelessWidget {
  final Verse verse;
  final bool highlight; // <<< الجديد
  final Bookmark? bookmark;

  const VerseCard({
    super.key,
    required this.verse,
    this.highlight = false,
    this.bookmark,
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
          color: bookmark != null
              ? Color(bookmark!.color)
              : highlight
                  ? Colors.teal.shade200
                  : Colors.white,
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
                if (bookmark != null)
                  _BookmarkBadge(bookmark: bookmark!),
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
                  onTap: () => showTafsirSheet(context, verse),
                ),
                _ActionButton(
                  icon: bookmark != null
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: bookmark != null
                      ? Color(bookmark!.color)
                      : Colors.grey.shade500,
                  onTap: () async {
                    final cubit = context.read<VerseCubit>();
                    final r = await showBookmarkSheet(context, bookmark);
                    if (r == null) return;
                    if (r.color == null) {
                      await cubit.removeBookmark(verse.id);
                    } else {
                      await cubit.saveBookmark(verse, r.color!, r.note);
                    }
                  },
                ),
                IconButton.filled(
                  icon: const Icon(Icons.play_arrow_rounded),
                  onPressed: () {
                    final cubit = context.read<VerseCubit>();
                    QuranPlayer.instance
                        .play([verse], suraName: cubit.suraName);
                    showPlayerSheet(
                      context,
                      onPlaySequential: () =>
                          cubit.playSequentiallyFrom(verse.id),
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

class _BookmarkBadge extends StatelessWidget {
  final Bookmark bookmark;
  const _BookmarkBadge({required this.bookmark});

  @override
  Widget build(BuildContext context) {
    final c = Color(bookmark.color);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.bookmark_rounded, color: c, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              bookmark.note ?? "علامة محفوظة",
              style: TextStyle(fontSize: 14, color: c, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
