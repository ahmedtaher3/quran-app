import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:untitled/features/Koran/data/model/ayah.dart';
import 'package:untitled/features/Koran/data/model/bookmark.dart';
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
      // ponytail: user tables live outside the versioned schema, so bumping
      // the version (which drops & re-imports content) never wipes user data.
      onOpen: (db) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS bookmarks (
            verse_id INTEGER PRIMARY KEY,
            sura INTEGER,
            aya INTEGER,
            color INTEGER,
            note TEXT,
            created_at INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS reading_log (
            day TEXT,
            verse_id INTEGER,
            PRIMARY KEY (day, verse_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS tafsir_cache (
            source INTEGER, sura INTEGER, aya INTEGER, text TEXT,
            PRIMARY KEY (source, sura, aya)
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS audio_timing (
            recitation INTEGER, sura INTEGER, json TEXT,
            PRIMARY KEY (recitation, sura)
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS hifz_cards (
            verse_id INTEGER PRIMARY KEY, sura INTEGER, ease REAL,
            interval INTEGER, reps INTEGER, due INTEGER
          )
        ''');
      },
    );
    return _db!;
  }

  static String dayKey(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  static Future<void> logVerses(Iterable<int> verseIds) async {
    if (verseIds.isEmpty) return;
    final db = await database;
    final day = dayKey(DateTime.now());
    final batch = db.batch();
    for (final id in verseIds) {
      batch.rawInsert(
          'INSERT OR IGNORE INTO reading_log (day, verse_id) VALUES (?, ?)',
          [day, id]);
    }
    await batch.commit(noResult: true);
  }

  static Future<void> logPages(int from, int to) async {
    final db = await database;
    await db.rawInsert('''
      INSERT OR IGNORE INTO reading_log (day, verse_id)
      SELECT ?, id FROM verses WHERE page BETWEEN ? AND ?
    ''', [dayKey(DateTime.now()), from, to]);
  }

  /// day -> verses read that day, newest first.
  static Future<Map<String, int>> versesPerDay() async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT day, COUNT(*) AS n FROM reading_log GROUP BY day ORDER BY day DESC');
    return {for (final r in rows) r['day'] as String: r['n'] as int};
  }

  /// Distinct verses / pages / suras ever read.
  static Future<({int verses, int pages, int suras})> readTotals() async {
    final db = await database;
    final r = (await db.rawQuery('''
      SELECT COUNT(DISTINCT v.id) AS verses,
             COUNT(DISTINCT v.page) AS pages,
             COUNT(DISTINCT v.sura) AS suras
      FROM reading_log l JOIN verses v ON v.id = l.verse_id
    ''')).first;
    return (
      verses: r['verses'] as int,
      pages: r['pages'] as int,
      suras: r['suras'] as int,
    );
  }

  static Future<void> upsertBookmark(Bookmark b) async {
    final db = await database;
    await db.insert('bookmarks', b.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> deleteBookmark(int verseId) async {
    final db = await database;
    await db.delete('bookmarks', where: 'verse_id = ?', whereArgs: [verseId]);
  }

  static Future<List<Bookmark>> getBookmarks({int? sura}) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT b.*, s.name AS suraName, v.text AS text
      FROM bookmarks b
      JOIN suras s ON s.number = b.sura
      JOIN verses v ON v.id = b.verse_id
      ${sura != null ? 'WHERE b.sura = ?' : ''}
      ORDER BY b.created_at DESC
    ''', sura != null ? [sura] : []);
    return maps.map(Bookmark.fromMap).toList();
  }

  /// First (or last) verse on a mushaf page, with its sura name.
  static Future<Verse?> getPageEdge(int page, {bool last = false}) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT verses.*, suras.name AS suraName
      FROM verses JOIN suras ON verses.sura = suras.number
      WHERE verses.page = ?
      ORDER BY verses.id ${last ? 'DESC' : 'ASC'} LIMIT 1
    ''', [page]);
    return maps.isEmpty ? null : Verse.fromJson(maps.first);
  }

  /// Verses with sura names: given suras, memorized ones, or everything.
  static Future<List<Verse>> getVersesWithNames(
      {List<int>? suras, bool memorizedOnly = false}) async {
    final db = await database;
    final where = memorizedOnly
        ? 'WHERE v.id IN (SELECT verse_id FROM hifz_cards)'
        : suras != null
            ? 'WHERE v.sura IN (${List.filled(suras.length, '?').join(',')})'
            : '';
    final maps = await db.rawQuery('''
      SELECT v.*, s.name AS suraName
      FROM verses v JOIN suras s ON v.sura = s.number
      $where ORDER BY v.id
    ''', memorizedOnly ? [] : suras ?? []);
    return maps.map(Verse.fromJson).toList();
  }

  /// Words of a sura in reading order, with their ayah's page/number.
  static Future<List<Map<String, Object?>>> getFlowWords(int sura) async {
    final db = await database;
    return db.rawQuery('''
      SELECT w.id, w.text, w.audio, w.translation, w.ayaID,
             v.ayaNumber, v.page
      FROM words w JOIN verses v ON v.id = w.ayaID
      WHERE w.sura = ? AND w.char_type = 'word'
      ORDER BY w.id
    ''', [sura]);
  }

  static Future<Verse?> getVerseById(int id) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT verses.*, suras.name AS suraName
      FROM verses JOIN suras ON verses.sura = suras.number
      WHERE verses.id = ?
    ''', [id]);
    return maps.isEmpty ? null : Verse.fromJson(maps.first);
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
