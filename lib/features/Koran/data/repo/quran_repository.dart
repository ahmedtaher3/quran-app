import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';
import 'package:untitled/features/Koran/data/model/sura.dart';
import 'package:untitled/features/Koran/data/model/ayah.dart';
import 'package:untitled/features/Koran/data/model/word.dart';

class QuranRepository {
  Future<List<Sura>> getAllSuras() async {
    return await DBHelper.getSuras();
  }

  Future<List<Verse>> getVersesBySura(int num) async {
    return await DBHelper.getVersesBySura(num);
  }

  Future<List<Word>> getWordsByAyah(int ayahId) async {
    return await DBHelper.getWordsByAyah(ayahId);
  }
}
