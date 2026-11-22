import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:untitled/core/notifications.dart';
import 'package:untitled/features/prayer/adhan_scheduler.dart';
import 'package:untitled/features/prayer/adhan_sound/adhan_catalog.dart';
import 'package:untitled/features/prayer/adhan_sound/adhan_sound_native.dart';
import 'package:untitled/features/prayer/adhan_sound/adhan_sound_prefs.dart';

class _Denied implements Exception {
  const _Denied();
}

/// State behind the adhan sound screen: the catalog, downloads, the two
/// choices (all prayers / Fajr) and the preview. Every select* call saves
/// the choice and replans the adhan, and returns the line to show the user
/// (null: nothing to say).
class AdhanSoundStore extends ChangeNotifier {
  AdhanSoundStore._();
  static final instance = AdhanSoundStore._();

  static const previewSeconds = 15;
  static const _failMsg = 'حدثت مشكلة، حاول مجددًا';
  static const _deniedMsg = 'نحتاج إذن التخزين ليتمكن الهاتف من تشغيل الصوت';

  AdhanSounds sounds = const AdhanSounds();
  List<AdhanCatalogItem> catalog = const [];
  bool catalogLoading = false;
  bool catalogFailed = false;

  final _progress = <String, double>{};

  /// Row key being previewed, its title and seconds played.
  String? previewing;
  String previewName = '';
  double previewPos = 0;
  Timer? _previewTimer;

  String? _dir;
  Future<void>? _loading;

  Future<void> load() => _loading ??= _load();

  /// The picker screen opened: the first time loads everything; later
  /// times re-fetch the catalog, so a voice added or removed shows up
  /// without restarting the app.
  Future<void> open() async {
    final first = _loading == null;
    await load();
    if (!first && !catalogLoading) unawaited(refreshCatalog());
  }

  Future<void> _load() async {
    _dir = '${(await getApplicationDocumentsDirectory()).path}/adhan';
    sounds = await AdhanSounds.load();
    catalog = await AdhanCatalog.cached();
    notifyListeners();
    unawaited(refreshCatalog());
  }

  Future<void> refreshCatalog() async {
    catalogLoading = true;
    catalogFailed = false;
    notifyListeners();
    try {
      catalog = await AdhanCatalog.fetch();
    } catch (_) {
      catalogFailed = true; // the cached list (if any) stays on screen
    } finally {
      catalogLoading = false;
      notifyListeners();
    }
  }

  /// A voice's Fajr recording is a separate file (and choice).
  String rowKey(AdhanCatalogItem it, {required bool fajr}) =>
      fajr && it.hasFajr ? '${it.id}_fajr' : it.id;

  File _fileFor(AdhanCatalogItem it, bool fajr) =>
      File('$_dir/${rowKey(it, fajr: fajr)}.mp3');

  bool isDownloaded(AdhanCatalogItem it, {required bool fajr}) =>
      _dir != null && _fileFor(it, fajr).existsSync();

  double? progressOf(AdhanCatalogItem it, {required bool fajr}) =>
      _progress[rowKey(it, fajr: fajr)];

  bool isSelected(AdhanCatalogItem it, {required bool fajr}) {
    final c = sounds.choiceFor(fajr: fajr);
    return c.kind == SoundKind.catalog && c.id == rowKey(it, fajr: fajr);
  }

  String _done(bool fajr, {bool downloaded = false}) =>
      '${downloaded ? 'تم التحميل، و' : ''}أصبح صوت ${fajr ? 'أذان الفجر' : 'الأذان'}';

  Future<String?> selectSystem({required bool fajr}) =>
      _apply(fajr, AdhanSoundChoice.system);

  Future<String?> selectSame() => _apply(true, AdhanSoundChoice.same);

  /// Downloads [it] once, then makes it the adhan for [fajr] or the rest.
  Future<String?> selectCatalog(AdhanCatalogItem it, {required bool fajr}) async {
    await load();
    final key = rowKey(it, fajr: fajr);
    if (_progress.containsKey(key) || isSelected(it, fajr: fajr)) return null;
    final file = _fileFor(it, fajr);
    final fresh = !file.existsSync();
    if (fresh) {
      try {
        await _download(it.urlFor(fajr: fajr), file, key, it.sizeFor(fajr: fajr));
      } catch (_) {
        return 'توقف التحميل. تأكد من الاتصال وحاول مجددًا';
      }
    }
    // the other prayer kind may already play this exact file
    final other = sounds.choiceFor(fajr: !fajr);
    var uri = other.kind == SoundKind.catalog && other.id == key ? other.uri : null;
    try {
      uri ??= await _publish(file.path,
          'adhan_${key}_${DateTime.now().millisecondsSinceEpoch}.mp3', it.name, 'audio/mpeg');
    } on _Denied {
      return _deniedMsg;
    } catch (_) {
      return _failMsg;
    }
    await _apply(fajr,
        AdhanSoundChoice(SoundKind.catalog, id: key, label: it.name, path: file.path, uri: uri));
    return _done(fajr, downloaded: fresh);
  }

  /// The system picker; the file is copied into the app, so deleting the
  /// original later doesn't break the adhan.
  Future<String?> pickFile({required bool fajr}) async {
    await load();
    final PickedSound? picked;
    try {
      picked = await AdhanSoundNative.pick();
    } on PlatformException catch (e) {
      return e.message == 'too_big' ? 'الملف أكبر من 20 م.ب، اختر ملفًا أصغر' : _failMsg;
    }
    if (picked == null) return null;
    final ext = _ext(picked.name);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    Directory(_dir!).createSync(recursive: true);
    final keep = File('$_dir/file_${fajr ? 'fajr' : 'all'}_$stamp$ext');
    try {
      await File(picked.path).copy(keep.path);
      await File(picked.path).delete();
    } catch (_) {
      return _failMsg;
    }
    final String uri;
    try {
      uri = await _publish(keep.path, 'adhan_file_$stamp$ext', _stem(picked.name), picked.mime);
    } on _Denied {
      keep.deleteSync();
      return _deniedMsg;
    } catch (_) {
      keep.deleteSync();
      return _failMsg;
    }
    await _apply(fajr,
        AdhanSoundChoice(SoundKind.file, label: picked.name, path: keep.path, uri: uri));
    return 'نُسخ الملف داخل التطبيق، و${_done(fajr)}';
  }

  static String _ext(String name) {
    final i = name.lastIndexOf('.');
    final e = i < 0 ? '' : name.substring(i).toLowerCase();
    return RegExp(r'^\.[a-z0-9]{1,5}$').hasMatch(e) ? e : '.mp3';
  }

  static String _stem(String name) {
    final i = name.lastIndexOf('.');
    return i <= 0 ? name : name.substring(0, i);
  }

  Future<void> _download(String url, File target, String key, int expected) async {
    Directory(_dir!).createSync(recursive: true);
    _setProgress(key, 0);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    // write to .part first so a killed download never looks complete
    final part = File('${target.path}.part');
    try {
      final res = await (await client.getUrl(Uri.parse(url))).close();
      if (res.statusCode != 200) throw HttpException('${res.statusCode}');
      final total = res.contentLength > 0 ? res.contentLength : expected;
      final sink = part.openWrite();
      var got = 0;
      try {
        await for (final chunk in res) {
          sink.add(chunk);
          got += chunk.length;
          if (total > 0) _setProgress(key, (got / total).clamp(0.0, 0.99));
        }
      } finally {
        await sink.close();
      }
      if (got == 0) throw const HttpException('empty');
      await part.rename(target.path);
    } catch (_) {
      if (part.existsSync()) part.deleteSync();
      rethrow;
    } finally {
      client.close();
      _progress.remove(key);
      notifyListeners();
    }
  }

  void _setProgress(String key, double v) {
    _progress[key] = v;
    notifyListeners();
  }

  /// Android 9 and older need storage access to share the file with the
  /// system; ask once and retry.
  Future<String> _publish(String path, String name, String title, String mime) async {
    try {
      return await AdhanSoundNative.publish(path: path, name: name, title: title, mime: mime);
    } on PlatformException catch (e) {
      if (e.code != 'permission') rethrow;
      if (!(await Permission.storage.request()).isGranted) throw const _Denied();
      return AdhanSoundNative.publish(path: path, name: name, title: title, mime: mime);
    }
  }

  Future<String?> _apply(bool fajr, AdhanSoundChoice choice) async {
    await load();
    final old = sounds;
    final prev = old.choiceFor(fajr: fajr);
    if (prev == choice) return null;
    final next = old.copyWith(fajr: fajr, choice: choice);
    sounds = next;
    notifyListeners();
    await AdhanSounds.save(next);
    // the replaced sound's shared copy (and a picked file's private one)
    if (prev.uri != null && !next.usedUris.contains(prev.uri)) {
      AdhanSoundNative.unpublish(prev.uri!).catchError((_) {});
      if (prev.kind == SoundKind.file && prev.path != null) {
        try {
          File(prev.path!).deleteSync();
        } catch (_) {}
      }
    }
    try {
      final allUri = next.uriFor(fajr: false);
      final fajrUri = next.uriFor(fajr: true);
      await Notifications.ensureAdhanChannel(allUri);
      if (fajrUri != allUri) {
        await Notifications.ensureAdhanChannel(fajrUri, name: 'أذان الفجر');
      }
      await AdhanScheduler.reschedule();
      await Notifications.dropAdhanChannelsExcept(
          {Notifications.adhanChannelFor(allUri), Notifications.adhanChannelFor(fajrUri)});
    } catch (e, st) {
      // the next app start replans from the saved choice anyway
      debugPrint('adhan sound: applying the choice failed: $e\n$st');
    }
    return null;
  }

  String previewSourceFor(AdhanCatalogItem it, {required bool fajr}) {
    final f = _fileFor(it, fajr);
    return f.existsSync() ? f.path : it.urlFor(fajr: fajr);
  }

  /// Lines for the screen to show that don't come from a tap's result
  /// (a preview that never started).
  final messages = StreamController<String>.broadcast();

  /// True between the tap and the audio actually starting.
  bool previewLoading = false;
  Timer? _giveUp;
  static const _previewFailed = 'تعذّر تشغيل العيّنة. تأكد من الاتصال وحاول مجددًا';

  /// Plays up to [previewSeconds] of [source]; the same [key] again stops.
  /// The clock only runs once audio starts; a remote file that hasn't
  /// started after 12 s (offline, slow) is given up with a message, since
  /// Android's player keeps retrying for a long time on its own.
  Future<void> togglePreview(String key, String name, String source) async {
    if (previewing == key) return stopPreview();
    await stopPreview();
    previewing = key;
    previewName = name;
    previewPos = 0;
    previewLoading = true;
    notifyListeners();
    AdhanSoundNative.onPreviewStarted = () {
      if (previewing != key || !previewLoading) return;
      _giveUp?.cancel();
      previewLoading = false;
      notifyListeners();
      _previewTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        previewPos += 0.25;
        if (previewPos >= previewSeconds) {
          stopPreview();
        } else {
          notifyListeners();
        }
      });
    };
    AdhanSoundNative.onPreviewDone = () {
      if (previewing != key) return;
      if (previewLoading) messages.add(_previewFailed);
      stopPreview();
    };
    _giveUp = Timer(const Duration(seconds: 12), () {
      if (previewing != key || !previewLoading) return;
      messages.add(_previewFailed);
      stopPreview();
    });
    try {
      await AdhanSoundNative.previewStart(source);
    } catch (_) {
      messages.add(_previewFailed);
      await stopPreview();
    }
  }

  Future<void> stopPreview() async {
    _previewTimer?.cancel();
    _previewTimer = null;
    _giveUp?.cancel();
    _giveUp = null;
    if (previewing == null) return;
    previewing = null;
    previewPos = 0;
    previewLoading = false;
    notifyListeners();
    try {
      await AdhanSoundNative.previewStop();
    } catch (_) {}
  }
}
