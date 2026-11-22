import 'package:flutter/services.dart';

/// A file the user picked, copied into the app's cache.
class PickedSound {
  final String path;
  final String name;
  final String mime;
  const PickedSound(this.path, this.name, this.mime);
}

/// Android side: android/app/src/main/kotlin/.../AdhanSoundChannel.kt.
class AdhanSoundNative {
  static const _ch = MethodChannel('tarik/adhan_sound');
  static bool _bound = false;

  /// Called once the preview's audio actually starts (a remote file may
  /// take a while, or never start when offline).
  static void Function()? onPreviewStarted;

  /// Called when a preview ends on its own (finished or failed to load).
  static void Function()? onPreviewDone;

  static void _bind() {
    if (_bound) return;
    _bound = true;
    _ch.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'previewStarted':
          onPreviewStarted?.call();
        case 'previewDone':
          onPreviewDone?.call();
      }
    });
  }

  /// Copies [path] into the shared Notifications folder and returns the
  /// content:// uri the notification channel can play. Throws a
  /// PlatformException with code "permission" on Android 9 and older when
  /// storage access is missing.
  static Future<String> publish({
    required String path,
    required String name,
    required String title,
    required String mime,
  }) async {
    final uri = await _ch.invokeMethod<String>(
        'publish', {'path': path, 'name': name, 'title': title, 'mime': mime});
    return uri!;
  }

  static Future<void> unpublish(String uri) =>
      _ch.invokeMethod('unpublish', {'uri': uri});

  /// The system file picker for audio; null when cancelled. Throws a
  /// PlatformException whose message is "too_big" over 20 MB.
  static Future<PickedSound?> pick() async {
    final r = await _ch.invokeMapMethod<String, String>('pick');
    if (r == null) return null;
    return PickedSound(r['path']!, r['name']!, r['mime']!);
  }

  /// [source]: a file path or an http(s) url.
  static Future<void> previewStart(String source) {
    _bind();
    return _ch.invokeMethod('previewStart', {'source': source});
  }

  static Future<void> previewStop() => _ch.invokeMethod('previewStop');
}
