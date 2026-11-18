import '../../../data/model/sura.dart';

abstract class SuraState {}

class SuraInitial extends SuraState {}

class SuraLoading extends SuraState {}

class SuraLoaded extends SuraState {
  final List<Sura> suras;
  final int? lastReadSura; // <<< الجديد
  final int? lastReadAya;
  final int? lastReadPage; // mushaf page of that ayah
  SuraLoaded(this.suras,
      {this.lastReadSura, this.lastReadAya, this.lastReadPage});
}

class SuraError extends SuraState {
  final String message;
  SuraError(this.message);
}

class SuraSearching extends SuraState {}

class SuraSearchResult extends SuraState {
  final List<Sura> results;
  SuraSearchResult(this.results);
}
