import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:untitled/features/Koran/data/model/ayah.dart';
import 'package:untitled/features/Koran/data/model/sura.dart';
import 'package:untitled/features/Koran/data/model/word.dart';
import 'package:sqflite/sqflite.dart';

class ImportIsolate {
  static Future<void> process(Database db, Function(double) onProgress) async {
    // 1. Process Suras
    final suraJson = await rootBundle.loadString('assets/surah.json');
    final suraList = await compute(_parseJson, suraJson);

    var batch = db.batch();
    for (int i = 0; i < suraList.length; i++) {
      batch.insert('suras', Sura.fromJson(suraList[i]).toMap());
    }
    await batch.commit(noResult: true);
    onProgress(0.1);
    await Future.delayed(Duration.zero);

    // 2. Process Verses
    final verseJson = await rootBundle.loadString('assets/ayah.json');
    final verseList = await compute(_parseJson, verseJson);

    int verseChunkSize = 1000;
    for (int i = 0; i < verseList.length; i += verseChunkSize) {
      int end = (i + verseChunkSize > verseList.length)
          ? verseList.length
          : i + verseChunkSize;
      batch = db.batch();
      for (int j = i; j < end; j++) {
        batch.insert('verses', Verse.fromJson(verseList[j]).toMap());
      }
      await batch.commit(noResult: true);
      onProgress(0.1 + (0.3 * (end / verseList.length)));
      await Future.delayed(Duration.zero);
    }

    // 3. Process Words
    final wordsJson = await rootBundle.loadString('assets/kalemat.json');
    final wordsList = await compute(_parseJson, wordsJson);

    int total = wordsList.length;
    int chunkSize =
        2000; // Smaller chunk size for words to keep main thread free

    for (int i = 0; i < total; i += chunkSize) {
      int end = (i + chunkSize > total) ? total : i + chunkSize;

      batch = db.batch();
      for (int j = i; j < end; j++) {
        batch.insert('words', Word.fromJson(wordsList[j]).toMap());
      }
      await batch.commit(noResult: true);

      onProgress(0.4 + ((end / total) * 0.6));

      // Crucial: yield control back to the UI thread
      await Future.delayed(Duration.zero);
    }
  }

  static dynamic _parseJson(String jsonString) {
    return jsonDecode(jsonString);
  }
}
