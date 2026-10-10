import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';
import '../../../data/repo/quran_repository.dart';
import '../../../data/model/sura.dart';
import 'sura_state.dart';

class SuraCubit extends Cubit<SuraState> {
  final QuranRepository repo;

  List<Sura> allSuras = [];

  SuraCubit(this.repo) : super(SuraInitial());

  Future<void> loadSuras() async {
    try {
      emit(SuraLoading());

      allSuras = await repo.getAllSuras();

      await refreshLastRead(force: true);
    } catch (e) {
      emit(SuraError(e.toString()));
    }
  }

  // فنكشن لتحديث موضع القراءة فوراً في الواجهة
  Future<void> refreshLastRead({bool force = false}) async {
    if (!force && state is! SuraLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    final lastSura = prefs.getInt("global_last_sura");
    final lastAyahId = prefs.getInt("global_last_ayah_id");
    final verse =
        lastAyahId == null ? null : await DBHelper.getVerseById(lastAyahId);
    emit(SuraLoaded(allSuras,
        lastReadSura: lastSura, lastReadAya: verse?.ayaNumber));
  }

  void searchSuras(String query) {
    print("Searching for: $query");

    if (query.trim().isEmpty) {
      print("Empty query → returning all suras");
      emit(SuraLoaded(allSuras));
      return;
    }

    emit(SuraSearching());

    final result = allSuras.where((sura) {
      return sura.name.contains(query) ||
          sura.englishName.contains(query) ||
          sura.number.toString().contains(query);
    }).toList();

    print("Search results: ${result.length}");

    emit(SuraSearchResult(result));
  }
}
