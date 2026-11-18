import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';
import 'package:untitled/features/Koran/data/model/ayah.dart';
import 'package:untitled/features/Koran/data/model/sura.dart';
import 'package:untitled/features/Koran/data/model/bookmark.dart';
import 'package:untitled/features/Koran/presentation/manager/cubit/verse_cubit.dart';
import 'package:untitled/features/Koran/presentation/manager/cubit/verse_state.dart';
import 'package:untitled/features/Koran/presentation/view/widgets/audio_player_sheet.dart';
import 'package:untitled/features/Koran/presentation/view/widgets/bookmark_sheet.dart';
import 'package:untitled/features/audio/quran_player.dart';

/// Pieces shared by both reading modes (ayah cards and continuous text), so
/// the two stay feature-for-feature the same.

/// Asks whether to stop the recitation when leaving the reader mid-play.
/// Returns true when the reader may close.
Future<bool> confirmLeaveWhilePlaying(
    BuildContext context, VerseState state) async {
  if (state is VerseLoaded && state.playingAyahId != null) {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("تنبيه", style: TextStyle(fontFamily: 'Hafs')),
        content: const Text(
          "هل تريد إيقاف التلاوة أم الاستمرار في الخلفية؟",
          style: TextStyle(fontFamily: 'Hafs'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.read<VerseCubit>().stopSequentialPlay();
              Navigator.pop(dialogContext, true);
            },
            child: const Text("إيقاف",
                style: TextStyle(color: Colors.red, fontFamily: 'Hafs')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("استمرار", style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );
    return result ?? false;
  }
  return true;
}

/// "Continue from where you stopped?" shown when a sura with a saved
/// position is opened.
void showContinueReadingDialog(
  BuildContext context, {
  required VoidCallback onContinue,
  required VoidCallback onRestart,
}) {
  Future.delayed(const Duration(milliseconds: 300), () {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("متابعة القراءة"),
        content: const Text("تريد تكملة القراءة من حيث توقفت؟"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onContinue();
            },
            child: const Text("نعم، متابعة"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onRestart();
            },
            child: const Text("البدء من جديد"),
          ),
        ],
      ),
    );
  });
}

/// Play-all button, or the mini player while this sura is reciting.
Widget? readerFab(BuildContext context, VerseState state, String suraName) {
  if (state is! VerseLoaded) return null;
  if (state.playingAyahId != null) {
    return MiniPlayer(
      verse: state.verses.firstWhere((v) => v.id == state.playingAyahId,
          orElse: () => state.verses.first),
      suraName: suraName,
      onStop: () => context.read<VerseCubit>().stopSequentialPlay(),
    );
  }
  return PlayAllButton(
    isPlaying: false,
    onTap: () => context.read<VerseCubit>().startSequentialPlay(),
  );
}

/// Plays one ayah and opens the player, which offers "continue from here".
void playSingleAyah(BuildContext context, Verse verse) {
  final cubit = context.read<VerseCubit>();
  QuranPlayer.instance.play([verse], suraName: cubit.suraName);
  showPlayerSheet(
    context,
    onPlaySequential: () => cubit.playSequentiallyFrom(verse.id),
  );
}

/// Add, recolor, re-note or remove the bookmark on [verse].
Future<void> editAyahBookmark(
    BuildContext context, Verse verse, Bookmark? bookmark) async {
  final cubit = context.read<VerseCubit>();
  final r = await showBookmarkSheet(context, bookmark);
  if (r == null) return;
  if (r.color == null) {
    await cubit.removeBookmark(verse.id);
  } else {
    await cubit.saveBookmark(verse, r.color!, r.note);
  }
}

class PlayAllButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const PlayAllButton({super.key, required this.isPlaying, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPlaying
                    ? [const Color(0xFFC62828), const Color(0xFFB71C1C)]
                    : [const Color(0xFF00695C), const Color(0xFF004D40)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color:
                      (isPlaying ? Colors.red : Colors.teal).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  isPlaying ? "إيقاف التشغيل" : "تشغيل الكل",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MiniPlayer extends StatelessWidget {
  final Verse verse;
  final String suraName;
  final VoidCallback onStop;
  const MiniPlayer(
      {super.key,
      required this.verse,
      required this.suraName,
      required this.onStop});

  @override
  Widget build(BuildContext context) {
    final qp = QuranPlayer.instance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        elevation: 8,
        shadowColor: Colors.teal.withOpacity(0.3),
        color: const Color(0xFF004D40),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => showPlayerSheet(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("$suraName - آية ${verse.ayaNumber}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      Text(qp.reciterName,
                          maxLines: 1,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: "الآية السابقة",
                  icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                  onPressed: qp.previous,
                ),
                StreamBuilder<bool>(
                  stream: qp.player.playingStream,
                  initialData: qp.player.playing,
                  builder: (_, snap) => IconButton(
                    icon: Icon(
                        snap.data == true
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 40),
                    onPressed: () => snap.data == true
                        ? qp.player.pause()
                        : qp.player.play(),
                  ),
                ),
                IconButton(
                  tooltip: "الآية التالية",
                  icon: const Icon(Icons.skip_previous_rounded,
                      color: Colors.white),
                  onPressed: qp.next,
                ),
                IconButton(
                  tooltip: "إيقاف",
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: onStop,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _arDigits = '٠١٢٣٤٥٦٧٨٩';

/// [n] in Arabic-Indic digits, as the mushaf prints them.
String arNum(int n) =>
    '$n'.split('').map((d) => _arDigits[int.parse(d)]).join();

int juzOf(int hizbQuarter) => (hizbQuarter - 1) ~/ 8 + 1;

/// What the ayah opening quarter [hizbQuarter] starts, as the mushaf's
/// margin says it: "الجزء ٣", "الحزب ٦", "ربع الحزب ٦", ...
String quarterLabel(int hizbQuarter) {
  final q = hizbQuarter - 1;
  final hizb = arNum(q ~/ 4 + 1);
  switch (q % 4) {
    case 0:
      return q % 8 == 0 ? "الجزء ${arNum(q ~/ 8 + 1)}" : "الحزب $hizb";
    case 1:
      return "ربع الحزب $hizb";
    case 2:
      return "نصف الحزب $hizb";
    default:
      return "ثلاثة أرباع الحزب $hizb";
  }
}

/// Previous / next sura at the end of a sura, in both reading modes.
class SuraNavFooter extends StatelessWidget {
  final int sura;
  final void Function(Sura) onOpen;
  const SuraNavFooter({super.key, required this.sura, required this.onOpen});

  static Future<List<Sura>>? _suras; // read once; the list never changes

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Sura>>(
      future: _suras ??= DBHelper.getSuras(),
      builder: (context, snap) {
        final all = snap.data;
        if (all == null) return const SizedBox(height: 72);
        Sura? find(int n) => all.where((s) => s.number == n).firstOrNull;
        final prev = find(sura - 1), next = find(sura + 1);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              if (prev != null)
                Expanded(
                  child: _SuraNavButton(
                      sura: prev, forward: false, onTap: () => onOpen(prev)),
                ),
              if (prev != null && next != null) const SizedBox(width: 12),
              if (next != null)
                Expanded(
                  child: _SuraNavButton(
                      sura: next, forward: true, onTap: () => onOpen(next)),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SuraNavButton extends StatelessWidget {
  final Sura sura;
  final bool forward;
  final VoidCallback onTap;
  const _SuraNavButton(
      {required this.sura, required this.forward, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF00695C);
    final fg = forward ? Colors.white : teal;
    final label = Column(
      crossAxisAlignment:
          forward ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(forward ? "السورة التالية" : "السورة السابقة",
            style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 12)),
        Text(sura.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: fg, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
    // arrow_back/forward mirror in RTL, so "forward" points left
    final arrow = Icon(forward ? Icons.arrow_forward : Icons.arrow_back,
        color: fg, size: 20);
    return Material(
      color: forward ? teal : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: teal),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: forward
                ? [Expanded(child: label), const SizedBox(width: 8), arrow]
                : [arrow, const SizedBox(width: 8), Expanded(child: label)],
          ),
        ),
      ),
    );
  }
}
