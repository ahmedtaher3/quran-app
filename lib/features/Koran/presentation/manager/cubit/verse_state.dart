import '../../../data/model/ayah.dart';
import '../../../data/model/bookmark.dart';

abstract class VerseState {}

class VerseInitial extends VerseState {}

class VerseLoading extends VerseState {}

class VerseLoaded extends VerseState {
  final List<Verse> verses;
  final int? lastViewedAyahId;
  final bool showContinueDialog;
  final int? playingAyahId; // <<< الجديد
  final Map<int, Bookmark> bookmarks; // verseId -> bookmark

  VerseLoaded(
    this.verses, {
    this.lastViewedAyahId,
    this.showContinueDialog = false,
    this.playingAyahId,
    this.bookmarks = const {},
  });
}

class VerseError extends VerseState {
  final String message;
  VerseError(this.message);
}
