import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';
import 'package:untitled/features/Koran/data/model/ayah.dart';
import 'package:untitled/features/audio/audio_downloads.dart';

class Reciter {
  final String id; // "<bitrate>/<edition>" on cdn.islamic.network
  final String name;
  const Reciter(this.id, this.name);
}

const reciters = [
  Reciter('128/ar.alafasy', 'مشاري العفاسي'),
  Reciter('192/ar.abdulbasitmurattal', 'عبد الباسط (مرتل)'),
  Reciter('128/ar.husary', 'محمود خليل الحصري'),
  Reciter('128/ar.husarymujawwad', 'الحصري (مجود)'),
  Reciter('128/ar.minshawi', 'محمد صديق المنشاوي'),
  Reciter('64/ar.minshawimujawwad', 'المنشاوي (مجود)'),
  Reciter('192/ar.abdurrahmaansudais', 'عبد الرحمن السديس'),
  Reciter('64/ar.saoodshuraym', 'سعود الشريم'),
  Reciter('128/ar.mahermuaiqly', 'ماهر المعيقلي'),
  Reciter('128/ar.shaatree', 'أبو بكر الشاطري'),
  Reciter('128/ar.ahmedajamy', 'أحمد العجمي'),
  Reciter('128/ar.hudhaify', 'علي الحذيفي'),
  Reciter('128/ar.muhammadayyoub', 'محمد أيوب'),
  Reciter('128/ar.muhammadjibreel', 'محمد جبريل'),
  Reciter('192/ar.abdullahbasfar', 'عبد الله بصفر'),
  Reciter('192/ar.hanirifai', 'هاني الرفاعي'),
];

/// quran.com recitation ids for reciters that have word timings.
const _qdcIds = {
  '128/ar.alafasy': 7,
  '192/ar.abdulbasitmurattal': 2,
  '128/ar.husary': 6,
  '128/ar.minshawi': 9,
  '64/ar.minshawimujawwad': 8,
  '192/ar.abdurrahmaansudais': 3,
  '64/ar.saoodshuraym': 10,
  '128/ar.shaatree': 4,
  '192/ar.hanirifai': 5,
};

/// Audio url + word segments ([_, wordPos, startMs, endMs]) for one verse.
class VerseTiming {
  final String url;
  final List<List<int>> segments;
  VerseTiming(this.url, this.segments);

  /// Last word that has started by [ms]; holds through the gaps between
  /// words so the highlight doesn't flicker.
  int? wordAt(int ms) {
    int? word;
    for (final s in segments) {
      if (s.length >= 4 && ms >= s[2]) word = s[1];
    }
    return word;
  }
}

/// The app's only audio player (just_audio_background allows one).
/// A queue is a list of verses; "repeat each ayah N times" is done by
/// putting each verse N times in the playlist, "repeat range" by LoopMode.all.
class QuranPlayer {
  QuranPlayer._();
  static final instance = QuranPlayer._();

  final player = AudioPlayer();
  List<Verse> _queue = [];
  String? _suraName;
  int _repeatEach = 1;

  String reciterId = reciters.first.id;
  double speed = 1.0;
  int repeatEach = 1; // applied on next play()
  bool loopRange = false;

  /// The verse currently playing (null when idle, done, or on a word clip).
  late final Stream<Verse?> currentVerse = _currentVerse();

  Stream<Verse?> _currentVerse() {
    final out = StreamController<Verse?>.broadcast();
    Verse? last;
    var lastSet = false;
    void push() {
      final st = player.processingState;
      final v = (st == ProcessingState.idle || st == ProcessingState.completed)
          ? null
          : current;
      if (lastSet && v?.id == last?.id) return;
      lastSet = true;
      last = v;
      out.add(v);
    }

    player.currentIndexStream.listen((_) => push());
    player.processingStateStream.listen((_) => push());
    return out.stream;
  }

  Verse? get current {
    final i = player.currentIndex;
    if (i == null || _queue.isEmpty) return null;
    return _queue[(i ~/ _repeatEach).clamp(0, _queue.length - 1)];
  }

  /// verseId -> timing, for the current reciter's loaded suras.
  final Map<int, VerseTiming> _timing = {};
  String? _timingReciter;

  bool get hasWordTiming => _qdcIds.containsKey(reciterId);

  /// 1-based position of the word being recited, or null.
  late final Stream<int?> currentWord = player.positionStream
      .map((pos) => _timing[current?.id]?.wordAt(pos.inMilliseconds))
      .distinct()
      .asBroadcastStream();

  Future<void> _loadTiming(List<Verse> verses) async {
    final rec = _qdcIds[reciterId];
    if (_timingReciter != reciterId) {
      _timing.clear();
      _timingReciter = reciterId;
    }
    if (rec == null) return;
    final suras = verses.map((v) => v.sura).toSet();
    for (final sura in suras) {
      if (verses.any((v) => v.sura == sura && !_timing.containsKey(v.id))) {
        try {
          final files = await _fetchChapter(rec, sura);
          final idByKey = {
            for (final v in verses.where((v) => v.sura == sura))
              '${v.sura}:${v.ayaNumber}': v.id
          };
          for (final f in files) {
            final id = idByKey[f['verse_key']];
            if (id == null) continue;
            _timing[id] = VerseTiming(
              _absUrl(f['url'] as String),
              [
                for (final seg in (f['segments'] as List? ?? []))
                  // some recitations send numbers as strings
                  [for (final n in seg as List) num.parse('$n').toInt()]
              ],
            );
          }
        } catch (_) {
          // offline/API down: fall back to plain audio without word timing
        }
      }
    }
  }

  static String _absUrl(String u) => u.startsWith('http')
      ? u
      : u.startsWith('//')
          ? 'https:$u'
          : 'https://verses.quran.com/$u';

  Future<List> _fetchChapter(int rec, int sura) async {
    final db = await DBHelper.database;
    final hit = await db.query('audio_timing',
        where: 'recitation = ? AND sura = ?', whereArgs: [rec, sura]);
    if (hit.isNotEmpty) return jsonDecode(hit.first['json'] as String);

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(Uri.parse(
          'https://api.quran.com/api/v4/recitations/$rec/by_chapter/$sura?fields=segments&per_page=300'));
      final res = await req.close();
      if (res.statusCode != 200) throw HttpException('${res.statusCode}');
      final files = jsonDecode(await res.transform(utf8.decoder).join())[
          'audio_files'] as List;
      await db.insert(
          'audio_timing', {'recitation': rec, 'sura': sura, 'json': jsonEncode(files)});
      return files;
    } finally {
      client.close();
    }
  }

  List<Verse> get queue => _queue;
  String? get suraName => _suraName;

  Future<void> loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    reciterId = p.getString('reciter') ?? reciterId;
    speed = p.getDouble('play_speed') ?? 1.0;
    repeatEach = p.getInt('repeat_each') ?? 1;
    loopRange = p.getBool('loop_range') ?? false;
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('reciter', reciterId);
    await p.setDouble('play_speed', speed);
    await p.setInt('repeat_each', repeatEach);
    await p.setBool('loop_range', loopRange);
  }

  String _remoteUrl(Verse v) =>
      _timing[v.id]?.url ??
      'https://cdn.islamic.network/quran/audio/$reciterId/${v.id}.mp3';

  /// Same urls playback would stream, so downloads keep word timings aligned.
  Future<List<String>> remoteUrls(List<Verse> verses) async {
    await _loadTiming(verses);
    return verses.map(_remoteUrl).toList();
  }

  AudioSource _sourceFor(Verse v, MediaItem tag) {
    final local = AudioDownloads.instance.localFile(reciterId, v.id);
    return local != null
        ? AudioSource.file(local.path, tag: tag)
        : AudioSource.uri(Uri.parse(_remoteUrl(v)), tag: tag);
  }

  String get reciterName =>
      reciters.firstWhere((r) => r.id == reciterId, orElse: () => reciters[0]).name;

  Future<void> play(List<Verse> verses,
      {int start = 0, String? suraName}) async {
    if (verses.isEmpty) return;
    await _loadTiming(verses);
    _queue = verses;
    _suraName = suraName;
    _repeatEach = repeatEach;
    final sources = <AudioSource>[
      for (final v in verses)
        for (var r = 0; r < _repeatEach; r++)
          _sourceFor(
            v,
            MediaItem(
              id: '${v.id}-$r',
              album: reciterName,
              title:
                  '${v.suraName ?? suraName ?? 'سورة ${v.sura}'} - آية ${v.ayaNumber}',
              artist: reciterName,
            ),
          ),
    ];
    await player.setLoopMode(loopRange ? LoopMode.all : LoopMode.off);
    await player.setSpeed(speed);
    await player.setAudioSources(sources, initialIndex: start * _repeatEach);
    player.play();
  }

  /// One-off clip (word pronunciation); replaces any queue.
  Future<void> playClip(String url, {String title = ''}) async {
    _queue = [];
    await player.setLoopMode(LoopMode.off);
    await player.setAudioSource(AudioSource.uri(Uri.parse(url),
        tag: MediaItem(id: url, title: title)));
    player.play();
  }

  Future<void> stop() async {
    _queue = [];
    await player.stop();
  }

  Future<void> next() async {
    final i = player.currentIndex;
    if (i == null) return;
    final target = (i ~/ _repeatEach + 1) * _repeatEach;
    if (target < (player.sequence.length)) {
      await player.seek(Duration.zero, index: target);
    }
  }

  Future<void> previous() async {
    final i = player.currentIndex;
    if (i == null) return;
    final target = ((i ~/ _repeatEach) - 1) * _repeatEach;
    await player.seek(Duration.zero, index: target < 0 ? 0 : target);
  }

  Future<void> setSpeed(double s) async {
    speed = s;
    await player.setSpeed(s);
    await _savePrefs();
  }

  Future<void> setLoopRange(bool on) async {
    loopRange = on;
    await player.setLoopMode(on ? LoopMode.all : LoopMode.off);
    await _savePrefs();
  }

  /// Takes effect immediately by rebuilding the queue at the current verse.
  Future<void> setRepeatEach(int n) async {
    repeatEach = n;
    await _savePrefs();
    await _restartAtCurrent();
  }

  Future<void> setReciter(String id) async {
    reciterId = id;
    await _savePrefs();
    await _restartAtCurrent();
  }

  Future<void> _restartAtCurrent() async {
    final cur = current;
    if (cur == null || !player.playing) return;
    await play(_queue, start: _queue.indexOf(cur), suraName: _suraName);
  }

  /// Log played verses for stats. Call once at startup.
  void startLogging() {
    currentVerse.listen((v) {
      if (v != null) DBHelper.logVerses([v.id]);
    });
  }
}
