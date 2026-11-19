import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled/core/app_theme.dart';
import 'package:untitled/features/audio/audio_downloads.dart';
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

const _teal = Color(0xFF00695C);

/// The reader's header, the same in both modes: back, the sura's name, and
/// a ⋮ menu holding everything else.
PreferredSizeWidget readerAppBar({required int sura, required String suraName}) {
  return AppBar(
    backgroundColor: _teal,
    iconTheme: const IconThemeData(color: Colors.white),
    centerTitle: true,
    // shrink long names rather than cut them
    title: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(suraName, style: const TextStyle(color: Colors.white)),
    ),
    actions: [ReaderMenu(sura: sura)],
  );
}

enum _MenuItem { fontSize, mode, download, recitation }

/// ⋮ menu: font size, reading mode, offline download, recitation settings.
/// A running download also shows as a ring beside it, tap to cancel.
class ReaderMenu extends StatefulWidget {
  final int sura;
  const ReaderMenu({super.key, required this.sura});

  @override
  State<ReaderMenu> createState() => _ReaderMenuState();
}

class _ReaderMenuState extends State<ReaderMenu> {
  final _dl = AudioDownloads.instance;
  bool _complete = false; // every ayah downloaded for the current reciter

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final total = (await DBHelper.getVersesBySura(widget.sura)).length;
    final done = await _dl.downloadedCount(
        QuranPlayer.instance.reciterId, widget.sura);
    if (mounted) setState(() => _complete = done >= total);
  }

  Future<void> _download() async {
    try {
      await _dl.downloadSura(widget.sura);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("تعذّر التحميل، تحقق من الإنترنت")));
      }
    }
    _check();
  }

  void _onSelected(_MenuItem item) {
    switch (item) {
      case _MenuItem.fontSize:
        showFontSizeSheet(context);
      case _MenuItem.mode:
        final s = AppSettings.instance;
        s.update(flowReading: !s.flowReading);
      case _MenuItem.download:
        if (_dl.progress.value.containsKey(widget.sura)) {
          _dl.cancel(widget.sura);
        } else {
          _download();
        }
      case _MenuItem.recitation:
        // the reciter may change, and downloads are per reciter
        showPlayerSheet(context, settingsOnly: true).then((_) => _check());
    }
  }

  PopupMenuItem<_MenuItem> _item(_MenuItem value, IconData icon, String label,
          {bool enabled = true}) =>
      PopupMenuItem(
        value: value,
        enabled: enabled,
        child: Row(
          children: [
            Icon(icon, color: enabled ? _teal : Colors.grey),
            const SizedBox(width: 12),
            Text(label),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<int, double>>(
      valueListenable: _dl.progress,
      builder: (context, progress, _) {
        final p = progress[widget.sura];
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (p != null)
              IconButton(
                tooltip: "إلغاء التحميل",
                onPressed: () => _dl.cancel(widget.sura),
                icon: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      value: p, strokeWidth: 2.5, color: Colors.white),
                ),
              ),
            PopupMenuButton<_MenuItem>(
              tooltip: "المزيد",
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              onSelected: _onSelected,
              itemBuilder: (_) {
                final flow = AppSettings.instance.flowReading;
                return [
                  _item(_MenuItem.fontSize, Icons.format_size_rounded,
                      "حجم الخط"),
                  _item(
                      _MenuItem.mode,
                      flow ? Icons.view_agenda_rounded : Icons.subject_rounded,
                      flow ? "عرض الآيات كبطاقات" : "عرض متصل كالمصحف"),
                  if (p != null)
                    _item(_MenuItem.download, Icons.close_rounded,
                        "إلغاء التحميل (${arNum((p * 100).round())}٪)")
                  else if (_complete)
                    _item(_MenuItem.download, Icons.offline_pin_rounded,
                        "السورة محمّلة", enabled: false)
                  else
                    _item(_MenuItem.download, Icons.download_rounded,
                        "تحميل السورة"),
                  _item(_MenuItem.recitation, Icons.tune_rounded,
                      "إعدادات التلاوة"),
                ];
              },
            ),
          ],
        );
      },
    );
  }
}

/// Font size with a live preview, so it can be tuned without reopening the
/// menu for every step. Applies to both reading modes.
void showFontSizeSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    useSafeArea: true,
    builder: (_) => const _FontSizeSheet(),
  );
}

class _FontSizeSheet extends StatelessWidget {
  const _FontSizeSheet();

  static const _min = 18.0, _max = 44.0;

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final size = s.quranSize.clamp(_min, _max).toDouble();
        void set(double v) => s.update(quranSize: v.clamp(_min, _max));
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("حجم الخط",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.heading)),
              const SizedBox(height: 16),
              Text('بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                  textAlign: TextAlign.center,
                  style: s.quranStyle(color: AppColors.heading)),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: "تصغير الخط",
                    icon: const Icon(Icons.text_decrease_rounded),
                    onPressed: size <= _min ? null : () => set(size - 2),
                  ),
                  Expanded(
                    child: Slider(
                      min: _min,
                      max: _max,
                      divisions: 13,
                      value: size,
                      label: arNum(size.round()),
                      onChanged: set,
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: "تكبير الخط",
                    icon: const Icon(Icons.text_increase_rounded),
                    onPressed: size >= _max ? null : () => set(size + 2),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
