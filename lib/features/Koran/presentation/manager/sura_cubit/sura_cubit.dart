import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

      // تحميل موضع القراءة الأخير أيضاً
      final prefs = await SharedPreferences.getInstance();
      final lastSura = prefs.getInt("global_last_sura");

      emit(SuraLoaded(allSuras, lastReadSura: lastSura));
    } catch (e) {
      emit(SuraError(e.toString()));
    }
  }

  // فنكشن لتحديث موضع القراءة فوراً في الواجهة
  Future<void> refreshLastRead() async {
    if (state is SuraLoaded) {
      final prefs = await SharedPreferences.getInstance();
      final lastSura = prefs.getInt("global_last_sura");
      emit(SuraLoaded(allSuras, lastReadSura: lastSura));
    }
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
