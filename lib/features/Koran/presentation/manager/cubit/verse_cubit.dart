import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled/AudioManager.dart';
import 'package:untitled/features/Koran/presentation/manager/cubit/verse_state.dart';
import 'package:untitled/core/constants/app_constants.dart';
import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';
import 'package:untitled/features/Koran/data/model/ayah.dart';
import 'package:untitled/features/Koran/data/model/bookmark.dart';
import '../../../data/repo/quran_repository.dart';

class VerseCubit extends Cubit<VerseState> {
  final QuranRepository repo;

  int? lastViewedAyahId;
  int? currentSuraNumber; // <<< الجديد
  bool shouldShowContinueDialog = false;

  Map<int, Bookmark> bookmarks = {};

  VerseCubit(this.repo) : super(VerseInitial());

  /// [skipContinueDialog]: opened at a specific ayah, so don't ask.
  Future<void> loadVerses(int suraNumber,
      {bool skipContinueDialog = false}) async {
    currentSuraNumber = suraNumber; // حفظ السورة الحالية
    try {
      emit(VerseLoading());

      final verses = await repo.getVersesBySura(suraNumber);
      bookmarks = {
        for (final b in await DBHelper.getBookmarks(sura: suraNumber))
          b.verseId: b
      };

      await loadLastViewedAyah(suraNumber, verses);
      if (skipContinueDialog) shouldShowContinueDialog = false;

      emit(VerseLoaded(
        verses,
        bookmarks: bookmarks,
        lastViewedAyahId: lastViewedAyahId,
        showContinueDialog: shouldShowContinueDialog,
      ));
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

    if (state is VerseLoaded) {
      final verses = (state as VerseLoaded).verses;
      emit(VerseLoaded(
        verses,
        bookmarks: bookmarks,
        lastViewedAyahId: null,
        showContinueDialog: false,
      ));
    }
  }

  /// ⬅️ دي اللي UI بيستخدمها علشان ينط للآية المحفوظة
  void continueFromLastAyah() {
    if (state is VerseLoaded) {
      final verses = (state as VerseLoaded).verses;

      emit(VerseLoaded(
        verses,
        bookmarks: bookmarks,
        lastViewedAyahId: lastViewedAyahId,
        showContinueDialog: false,
      ));
    }
  }

  Future<void> updateReadingPosition(int suraNumber, int ayahId) async {
    if (lastViewedAyahId == ayahId) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("last_ayah_$suraNumber", ayahId);

    // 🔥 حفظ الموقع الأخير بشكل عام للوصول إليه من أي مكان
    await prefs.setInt("global_last_sura", suraNumber);
    await prefs.setInt("global_last_ayah_id", ayahId);

    lastViewedAyahId = ayahId;

    if (state is VerseLoaded) {
      final verses = (state as VerseLoaded).verses;
      emit(VerseLoaded(
        verses,
        bookmarks: bookmarks,
        lastViewedAyahId: ayahId,
        showContinueDialog: false,
      ));
    }
  }

  void startSequentialPlay() {
    if (state is VerseLoaded) {
      final verseLoaded = state as VerseLoaded;
      final verses = verseLoaded.verses;
      if (verses.isEmpty) return;

      int startIndex = 0;
      if (lastViewedAyahId != null) {
        final savedIndex = verses.indexWhere((v) => v.id == lastViewedAyahId);
        if (savedIndex != -1) {
          startIndex = savedIndex;
        }
      }
      _playVerseAt(startIndex);
    }
  }

  void playSequentiallyFrom(int verseId) {
    if (state is VerseLoaded) {
      final verses = (state as VerseLoaded).verses;
      final index = verses.indexWhere((v) => v.id == verseId);
      if (index != -1) {
        _playVerseAt(index);
      }
    }
  }

  void _playVerseAt(int index) {
    if (state is VerseLoaded) {
      final verses = (state as VerseLoaded).verses;
      if (index >= verses.length) {
        stopSequentialPlay();
        return;
      }

      final verse = verses[index];
      final url = "${AppConstants.verseAudioBaseUrl}${verse.audio}";

      // تحديث آخر آية تم الوصول إليها تلقائياً مع التشغيل
      lastViewedAyahId = verse.id;
      DBHelper.logVerses([verse.id]);
      if (currentSuraNumber != null) {
        updateReadingPosition(currentSuraNumber!, verse.id);
      }

      // تحديث الحالة لتمييز الآية الحالية
      emit(VerseLoaded(
        verses,
        bookmarks: bookmarks,
        lastViewedAyahId: verse.id,
        showContinueDialog: false,
        playingAyahId: verse.id,
      ));

      AudioManager.playAyah(url);

      // ضبط الانتقال للآية التالية عند الانتهاء
      AudioManager.setOnComplete(() {
        _playVerseAt(index + 1);
      });
    }
  }

  void stopSequentialPlay() {
    if (state is VerseLoaded) {
      final verses = (state as VerseLoaded).verses;
      AudioManager.stop();
      emit(VerseLoaded(
        verses,
        bookmarks: bookmarks,
        lastViewedAyahId: lastViewedAyahId,
        showContinueDialog: false,
        playingAyahId: null,
      ));
    }
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
    _reemit();
  }

  Future<void> removeBookmark(int verseId) async {
    await DBHelper.deleteBookmark(verseId);
    bookmarks = Map.of(bookmarks)..remove(verseId);
    _reemit();
  }

  void _reemit() {
    final s = state;
    if (s is VerseLoaded) {
      emit(VerseLoaded(
        s.verses,
        bookmarks: bookmarks,
        lastViewedAyahId: s.lastViewedAyahId,
        playingAyahId: s.playingAyahId,
      ));
    }
  }

  /// ⬅️ علشان نقفل الدايلوج بعد ما يظهر مرة
  void clearDialogFlag() {
    shouldShowContinueDialog = false;
  }
}
