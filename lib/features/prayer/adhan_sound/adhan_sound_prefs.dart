import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Where an adhan sound comes from.
enum SoundKind {
  /// The phone's default notification tone.
  system,

  /// Fajr only: whatever the other prayers use.
  same,

  /// A file the user picked from the phone.
  file,

  /// A voice downloaded from the catalog.
  catalog,
}

/// One saved choice. [uri] is the MediaStore copy the notification channel
/// plays; [path] is the app's private copy, used for previews.
class AdhanSoundChoice {
  final SoundKind kind;
  final String? id;
  final String? label;
  final String? path;
  final String? uri;

  const AdhanSoundChoice(this.kind, {this.id, this.label, this.path, this.uri});

  static const system = AdhanSoundChoice(SoundKind.system);
  static const same = AdhanSoundChoice(SoundKind.same);

  /// A sound of its own (not the default tone, not "same as the others").
  bool get hasSound =>
      (kind == SoundKind.file || kind == SoundKind.catalog) && uri != null;

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        if (id != null) 'id': id,
        if (label != null) 'label': label,
        if (path != null) 'path': path,
        if (uri != null) 'uri': uri,
      };

  static AdhanSoundChoice fromJson(Object? json, AdhanSoundChoice fallback) {
    if (json is! Map) return fallback;
    final kind = SoundKind.values.where((k) => k.name == json['kind']).firstOrNull;
    if (kind == null) return fallback;
    return AdhanSoundChoice(
      kind,
      id: json['id'] as String?,
      label: json['label'] as String?,
      path: json['path'] as String?,
      uri: json['uri'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AdhanSoundChoice &&
      other.kind == kind &&
      other.id == id &&
      other.path == path &&
      other.uri == uri;

  @override
  int get hashCode => Object.hash(kind, id, path, uri);
}

/// Both choices, read by the UI and by the scheduler (also in the
/// background job, so nothing here touches Flutter widgets or plugins
/// other than shared_preferences).
class AdhanSounds {
  final AdhanSoundChoice all;
  final AdhanSoundChoice fajr;
  const AdhanSounds({this.all = AdhanSoundChoice.system, this.fajr = AdhanSoundChoice.same});

  static const _allKey = 'adhan_sound_all';
  static const _fajrKey = 'adhan_sound_fajr';

  static Future<AdhanSounds> load() async {
    final p = await SharedPreferences.getInstance();
    return AdhanSounds(
      all: _read(p.getString(_allKey), AdhanSoundChoice.system),
      fajr: _read(p.getString(_fajrKey), AdhanSoundChoice.same),
    );
  }

  static AdhanSoundChoice _read(String? raw, AdhanSoundChoice fallback) {
    if (raw == null) return fallback;
    try {
      return AdhanSoundChoice.fromJson(jsonDecode(raw), fallback);
    } catch (_) {
      return fallback;
    }
  }

  static Future<void> save(AdhanSounds s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_allKey, jsonEncode(s.all.toJson()));
    await p.setString(_fajrKey, jsonEncode(s.fajr.toJson()));
  }

  AdhanSoundChoice choiceFor({required bool fajr}) => fajr ? this.fajr : all;

  AdhanSounds copyWith({required bool fajr, required AdhanSoundChoice choice}) =>
      fajr ? AdhanSounds(all: all, fajr: choice) : AdhanSounds(all: choice, fajr: this.fajr);

  /// The sound uri a prayer's adhan plays; null = the default tone.
  String? uriFor({required bool fajr}) {
    final c = fajr && this.fajr.kind != SoundKind.same ? this.fajr : all;
    return c.hasSound ? c.uri : null;
  }

  /// Every MediaStore uri still in use, so a replaced one can be removed.
  Set<String> get usedUris =>
      {all.uri, fajr.uri}.whereType<String>().toSet();

  /// What the settings screen shows under "صوت الأذان" / "أذان الفجر".
  String labelFor({required bool fajr}) {
    final c = choiceFor(fajr: fajr);
    return switch (c.kind) {
      SoundKind.system => 'نغمة الإشعار الافتراضية',
      SoundKind.same => 'نفس صوت الأذان',
      SoundKind.file => 'ملف من هاتفك · ${c.label ?? ''}',
      SoundKind.catalog => c.label ?? 'صوت محمّل',
    };
  }
}
