import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';
import 'package:untitled/features/audio/quran_player.dart';

/// Per-reciter mp3 files under <documents>/audio/<reciter>/<verseId>.mp3.
class AudioDownloads {
  AudioDownloads._();
  static final instance = AudioDownloads._();

  String? _root;

  /// sura -> progress 0..1 while downloading.
  final progress = ValueNotifier<Map<int, double>>({});
  final _cancelled = <int>{};

  Future<void> init() async {
    _root ??= '${(await getApplicationDocumentsDirectory()).path}/audio';
  }

  String _dir(String reciterId) => '$_root/${reciterId.replaceAll('/', '_')}';

  /// Local file for a verse if it was downloaded (sync: called while
  /// building playlists).
  File? localFile(String reciterId, int verseId) {
    if (_root == null) return null;
    final f = File('${_dir(reciterId)}/$verseId.mp3');
    return f.existsSync() ? f : null;
  }

  Future<int> downloadedCount(String reciterId, int sura) async {
    await init();
    final verses = await DBHelper.getVersesBySura(sura);
    return verses.where((v) => localFile(reciterId, v.id) != null).length;
  }

  Future<void> downloadSura(int sura) async {
    await init();
    final qp = QuranPlayer.instance;
    final reciter = qp.reciterId;
    final verses = await DBHelper.getVersesBySura(sura);
    final urls = await qp.remoteUrls(verses);
    final dir = Directory(_dir(reciter))..createSync(recursive: true);
    _cancelled.remove(sura);
    _set(sura, 0);
    final client = HttpClient();
    try {
      for (var i = 0; i < verses.length; i++) {
        if (_cancelled.contains(sura)) break;
        final target = File('${dir.path}/${verses[i].id}.mp3');
        if (!target.existsSync()) {
          final req = await client.getUrl(Uri.parse(urls[i]));
          final res = await req.close();
          if (res.statusCode != 200) throw HttpException('${res.statusCode}');
          // write to .part first so a killed download never looks complete
          final part = File('${target.path}.part');
          await res.pipe(part.openWrite());
          await part.rename(target.path);
        }
        _set(sura, (i + 1) / verses.length);
      }
    } finally {
      client.close();
      _clear(sura);
    }
  }

  void cancel(int sura) => _cancelled.add(sura);

  Future<void> deleteSura(int sura) async {
    await init();
    final reciter = QuranPlayer.instance.reciterId;
    for (final v in await DBHelper.getVersesBySura(sura)) {
      localFile(reciter, v.id)?.deleteSync();
    }
  }

  Future<void> deleteAll() async {
    await init();
    final d = Directory(_root!);
    if (d.existsSync()) d.deleteSync(recursive: true);
  }

  Future<int> totalBytes() async {
    await init();
    final d = Directory(_root!);
    if (!d.existsSync()) return 0;
    var n = 0;
    await for (final e in d.list(recursive: true)) {
      if (e is File) n += await e.length();
    }
    return n;
  }

  void _set(int sura, double p) =>
      progress.value = {...progress.value, sura: p};

  void _clear(int sura) =>
      progress.value = Map.of(progress.value)..remove(sura);
}

String formatBytes(int b) {
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
  if (b < 1024 * 1024 * 1024) {
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}
