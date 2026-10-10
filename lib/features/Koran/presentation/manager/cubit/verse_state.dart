import '../../../data/model/ayah.dart';

abstract class VerseState {}

class VerseInitial extends VerseState {}

class VerseLoading extends VerseState {}

class VerseLoaded extends VerseState {
  final List<Verse> verses;
  final int? lastViewedAyahId;
  final bool showContinueDialog;
  final int? playingAyahId; // <<< الجديد

  VerseLoaded(
    this.verses, {
    this.lastViewedAyahId,
    this.showContinueDialog = false,
    this.playingAyahId,
  });
}

class VerseError extends VerseState {
  final String message;
  VerseError(this.message);
}
