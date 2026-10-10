import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:untitled/features/Koran/data/model/ayah.dart';
import 'package:untitled/features/Koran/data/model/sura.dart';
import 'package:untitled/features/Koran/data/model/word.dart';

class DBHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'verses.db');

    _db = await openDatabase(
      path,
      version: 7, // Bumping version to force recreate/upgrade
      onCreate: (db, version) async {
        await _createDb(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // If version changed, drop and recreate for simplicity (first time setup)
        await db.execute('DROP TABLE IF EXISTS suras');
        await db.execute('DROP TABLE IF EXISTS verses');
        await db.execute('DROP TABLE IF EXISTS words');
        await _createDb(db);
      },
    );
    return _db!;
  }

  static Future<void> _createDb(Database db) async {
    await db.execute('''
          CREATE TABLE suras (
            number INTEGER PRIMARY KEY,
            name TEXT,
            englishName TEXT,
            englishNameTranslation TEXT,
            ayahs INTEGER,
            revelationType TEXT
          )
        ''');

    await db.execute('''
          CREATE TABLE verses (
            id INTEGER PRIMARY KEY,
            ayaNumber INTEGER,
            sura INTEGER,
            page INTEGER,
            manzil INTEGER,
            ruku INTEGER,
            sajda INTEGER,
            hizbQuarter INTEGER,
            text TEXT,
            audio TEXT,
            audioPath TEXT,
            tafsir TEXT   
          )
        ''');

    await db.execute('''
           CREATE TABLE words (
            id INTEGER PRIMARY KEY,
            audio TEXT,
            aya INTEGER,
            ayaID INTEGER,
            char_type TEXT,
            code TEXT,
            code_v3 TEXT,
            simple TEXT,
            sura INTEGER,
            text TEXT,
            translation TEXT
          )
        ''');
  }

  static Future<void> insertSura(Sura sura) async {
    final db = await database;
    await db.insert('suras', sura.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> insertVerse(Verse verse) async {
    final db = await database;
    await db.insert('verses', verse.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> insertWord(Word word) async {
    final db = await database;
    await db.insert('words', word.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Sura>> getSuras() async {
    final db = await database;
    final maps = await db.query('suras');
    return maps.map((e) => Sura.fromJson(e)).toList();
  }

  static Future<List<Verse>> getVersesBySura(int suraNumber) async {
    final db = await database;
    final maps =
        await db.query('verses', where: 'sura = ?', whereArgs: [suraNumber]);
    return maps.map((e) => Verse.fromJson(e)).toList();
  }

  static Future<List<Word>> getWordsBySura(int suraNumber) async {
    final db = await database;
    final maps =
        await db.query('words', where: 'sura = ?', whereArgs: [suraNumber]);
    return maps.map((e) => Word.fromJson(e)).toList();
  }

  static Future<List<Word>> getWordsByAyah(int ayahId) async {
    final db = await database;
    final maps =
        await db.query('words', where: 'ayaID = ?', whereArgs: [ayahId]);
    return maps.map((e) => Word.fromJson(e)).toList();
  }

  static Future<bool> isDatabaseEmpty() async {
    final db = await database;
    // Check verses instead of suras to ensure content is fully loaded
    final count =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM verses'));
    // If we have less than 6236 (total Quran verses), consider it empty/incomplete
    return (count ?? 0) < 6236;
  }

  static Future<Verse?> getRandomVerse() async {
    final db = await database;
    try {
      final maps = await db.rawQuery('''
        SELECT verses.*, suras.name as suraName 
        FROM verses 
        JOIN suras ON verses.sura = suras.number 
        ORDER BY RANDOM() 
        LIMIT 1
      ''');
      if (maps.isNotEmpty) {
        return Verse.fromJson(maps.first);
      }
    } catch (e) {
      // In case table or column doesn't exist yet
      return null;
    }
    return null;
  }
}
