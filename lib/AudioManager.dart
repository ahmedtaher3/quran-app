import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

class AudioManager {
  static final AudioPlayer _player = AudioPlayer();

  static AudioPlayer get player => _player;

  static Future<void> playAyah(String url) async {
    try {
      await _player.stop();
      await _player.setSourceUrl(url);
      await _player.resume();
    } catch (e) {
      print("AudioManager error: $e");
    }
  }

  static Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  static Future<void> pause() async {
    try {
      await _player.pause();
    } catch (_) {}
  }

  static Future<void> resume() async {
    try {
      await _player.resume();
    } catch (_) {}
  }

  static StreamSubscription? _onCompleteSubscription;

  static void setOnComplete(void Function() callback) {
    _onCompleteSubscription?.cancel();
    _onCompleteSubscription = _player.onPlayerComplete.listen((event) {
      callback();
    });
  }

  static void setOnStateChanged(void Function(PlayerState state) callback) {
    _player.onPlayerStateChanged.listen((state) {
      callback(state);
    });
  }
}
