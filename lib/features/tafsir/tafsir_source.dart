import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';

class TafsirSource {
  final int id; // quran.com resource id; 0 = bundled Muyassar
  final String name;
  const TafsirSource(this.id, this.name);
}

const tafsirSources = [
  TafsirSource(0, "الميسر"),
  TafsirSource(91, "السعدي"),
  TafsirSource(14, "ابن كثير"),
  TafsirSource(15, "الطبري"),
  TafsirSource(90, "القرطبي"),
  TafsirSource(94, "البغوي"),
  TafsirSource(93, "الوسيط"),
];

class TafsirRepo {
  static const _prefKey = 'tafsir_source';

  static Future<int> preferred() async =>
      (await SharedPreferences.getInstance()).getInt(_prefKey) ?? 0;

  static Future<void> setPreferred(int id) async =>
      (await SharedPreferences.getInstance()).setInt(_prefKey, id);

  /// Cached forever after first fetch; throws on network failure.
  static Future<String> get(int sourceId, int sura, int aya) async {
    final db = await DBHelper.database;
    final hit = await db.query('tafsir_cache',
        where: 'source = ? AND sura = ? AND aya = ?',
        whereArgs: [sourceId, sura, aya]);
    if (hit.isNotEmpty) return hit.first['text'] as String;

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(Uri.parse(
          'https://api.quran.com/api/v4/tafsirs/$sourceId/by_ayah/$sura:$aya'));
      final res = await req.close();
      if (res.statusCode != 200) throw HttpException('${res.statusCode}');
      final body = jsonDecode(await res.transform(utf8.decoder).join());
      final t = body['tafsir'];
      var text = htmlToText(t['text'] ?? '');
      if (text.isEmpty) {
        // grouped tafsirs put the whole passage on the group's first ayah
        final keys = (t['verses'] as Map).keys.join('، ');
        text = "تفسير هذه الآية مذكور ضمن تفسير الآيات: $keys";
      }
      await db.insert('tafsir_cache',
          {'source': sourceId, 'sura': sura, 'aya': aya, 'text': text});
      return text;
    } finally {
      client.close();
    }
  }
}

String htmlToText(String html) => html
    .replaceAll(RegExp(r'<br\s*/?>|</p>|</h\d>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();
