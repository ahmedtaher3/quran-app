import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled/features/Koran/presentation/manager/cubit/verse_state.dart';
import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';
import 'package:untitled/features/Koran/data/model/ayah.dart';
import 'package:untitled/features/Koran/data/model/bookmark.dart';
import 'package:untitled/features/audio/quran_player.dart';
import '../../../data/repo/quran_repository.dart';

class VerseCubit extends Cubit<VerseState> {
  final QuranRepository repo;

  int? lastViewedAyahId;
  int? currentSuraNumber; // <<< الجديد
  String? suraName;
  bool shouldShowContinueDialog = false;
  int? playingAyahId;
  List<Verse> _verses = [];

  Map<int, Bookmark> bookmarks = {};

  StreamSubscription<Verse?>? _audioSub;

  VerseCubit(this.repo) : super(VerseInitial()) {
    _audioSub = QuranPlayer.instance.currentVerse.listen(_onPlayingVerse);
  }

  void _onPlayingVerse(Verse? v) {
    final here = v != null && v.sura == currentSuraNumber;
    playingAyahId = here ? v.id : null;
    if (here) {
      // تحديث آخر آية تم الوصول إليها تلقائياً مع التشغيل
      updateReadingPosition(v.sura, v.id);
    } else {
      _emit();
    }
  }

  void _emit({bool showContinueDialog = false, bool force = false}) {
    if (force || state is VerseLoaded) {
      emit(VerseLoaded(
        _verses,
        bookmarks: bookmarks,
        lastViewedAyahId: lastViewedAyahId,
        showContinueDialog: showContinueDialog,
        playingAyahId: playingAyahId,
      ));
    }
  }

  /// [skipContinueDialog]: opened at a specific ayah, so don't ask.
  Future<void> loadVerses(int suraNumber,
      {bool skipContinueDialog = false}) async {
    currentSuraNumber = suraNumber; // حفظ السورة الحالية
    try {
      emit(VerseLoading());

      _verses = await repo.getVersesBySura(suraNumber);
      bookmarks = {
        for (final b in await DBHelper.getBookmarks(sura: suraNumber))
          b.verseId: b
      };

      await loadLastViewedAyah(suraNumber, _verses);
      final cur = QuranPlayer.instance.current;
      if (QuranPlayer.instance.player.playing && cur?.sura == suraNumber) {
        playingAyahId = cur!.id;
        shouldShowContinueDialog = false;
      }
      if (skipContinueDialog) shouldShowContinueDialog = false;

      _emit(showContinueDialog: shouldShowContinueDialog, force: true);
    } catch (e) {
      emit(VerseError(e.toString()));
    }
  }

  Future<void> saveLastViewedAyah(int suraNumber, int ayahId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("last_ayah_$suraNumber", ayahId);
    lastViewedAyahId = ayahId;
  }

  Future<void> loadLastViewedAyah(int suraNumber, List verses) async {
    final prefs = await SharedPreferences.getInstance();
    lastViewedAyahId = prefs.getInt("last_ayah_$suraNumber");

    if (lastViewedAyahId != null) {
      final exists = verses.any((v) => v.id == lastViewedAyahId);
      shouldShowContinueDialog = exists;
    } else {
      shouldShowContinueDialog = false;
    }
  }

  Future<void> resetProgress(int suraNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("last_ayah_$suraNumber");
    lastViewedAyahId = null;
    shouldShowContinueDialog = false;
    _emit();
  }

  /// ⬅️ دي اللي UI بيستخدمها علشان ينط للآية المحفوظة
  void continueFromLastAyah() => _emit();

  Future<void> updateReadingPosition(int suraNumber, int ayahId) async {
    if (lastViewedAyahId == ayahId) {
      _emit(); // playingAyahId may still have changed
      return;
    }
    lastViewedAyahId = ayahId;
    _emit();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("last_ayah_$suraNumber", ayahId);

    // 🔥 حفظ الموقع الأخير بشكل عام للوصول إليه من أي مكان
    await prefs.setInt("global_last_sura", suraNumber);
    await prefs.setInt("global_last_ayah_id", ayahId);
  }

  void startSequentialPlay() {
    if (_verses.isEmpty) return;
    final saved = _verses.indexWhere((v) => v.id == lastViewedAyahId);
    _playFrom(saved == -1 ? 0 : saved);
  }

  void playSequentiallyFrom(int verseId) {
    final index = _verses.indexWhere((v) => v.id == verseId);
    if (index != -1) _playFrom(index);
  }

  void _playFrom(int index) {
    QuranPlayer.instance.play(_verses, start: index, suraName: suraName);
  }

  void stopSequentialPlay() {
    QuranPlayer.instance.stop();
    playingAyahId = null;
    _emit();
  }

  Future<void> saveBookmark(Verse verse, int color, String? note) async {
    final b = Bookmark(
      verseId: verse.id,
      sura: verse.sura,
      aya: verse.ayaNumber ?? 0,
      color: color,
      note: (note == null || note.trim().isEmpty) ? null : note.trim(),
      createdAt: bookmarks[verse.id]?.createdAt ??
          DateTime.now().millisecondsSinceEpoch,
    );
    await DBHelper.upsertBookmark(b);
    bookmarks = {...bookmarks, verse.id: b};
    _emit();
  }

  Future<void> removeBookmark(int verseId) async {
    await DBHelper.deleteBookmark(verseId);
    bookmarks = Map.of(bookmarks)..remove(verseId);
    _emit();
  }

  /// ⬅️ علشان نقفل الدايلوج بعد ما يظهر مرة
  void clearDialogFlag() {
    shouldShowContinueDialog = false;
  }

  @override
  Future<void> close() {
    _audioSub?.cancel(); // playback itself continues in the background
    return super.close();
  }
}
