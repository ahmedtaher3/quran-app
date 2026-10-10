import 'package:sqflite/sqflite.dart';
import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';
import 'package:untitled/features/Koran/data/model/ayah.dart';
import 'package:untitled/features/hifz/srs.dart';

class HifzStore {
  static Future<Database> get _db => DBHelper.database;

  /// Adds verses as new cards due today; existing cards are left alone.
  static Future<int> add(List<Verse> verses) async {
    final db = await _db;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final batch = db.batch();
    for (final v in verses) {
      batch.insert(
        'hifz_cards',
        SrsCard(verseId: v.id, sura: v.sura, due: today).toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    final res = await batch.commit();
    return res.where((r) => r is int && r > 0).length;
  }

  static Future<void> save(SrsCard c) async {
    await (await _db).insert('hifz_cards', c.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> removeSura(int sura) async {
    await (await _db).delete('hifz_cards', where: 'sura = ?', whereArgs: [sura]);
  }

  static Future<List<SrsCard>> all() async =>
      (await (await _db).query('hifz_cards')).map(SrsCard.fromMap).toList();

  /// Due cards with their verse, in mushaf order so recall flows naturally.
  static Future<List<(SrsCard, Verse)>> due() async {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day + 1);
    final rows = await (await _db).rawQuery('''
      SELECT c.*, v.*, s.name AS suraName
      FROM hifz_cards c
      JOIN verses v ON v.id = c.verse_id
      JOIN suras s ON s.number = v.sura
      WHERE c.due < ?
      ORDER BY v.id
    ''', [end.millisecondsSinceEpoch]);
    return [for (final r in rows) (SrsCard.fromMap(r), Verse.fromJson(r))];
  }

  /// Per-sura summary: sura -> (cards, avg strength).
  static Future<Map<int, ({int count, double strength})>> bySura() async {
    final m = <int, List<SrsCard>>{};
    for (final c in await all()) {
      (m[c.sura] ??= []).add(c);
    }
    return {
      for (final e in m.entries)
        e.key: (
          count: e.value.length,
          strength: e.value.map((c) => c.strength).reduce((a, b) => a + b) /
              e.value.length,
        )
    };
  }
}
