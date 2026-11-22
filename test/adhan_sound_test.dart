import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:untitled/core/notifications.dart';
import 'package:untitled/features/prayer/adhan_sound/adhan_catalog.dart';
import 'package:untitled/features/prayer/adhan_sound/adhan_sound_prefs.dart';

const _makkah = AdhanSoundChoice(SoundKind.catalog,
    id: 'makkah', label: 'أذان الحرم المكي', path: '/a/makkah.mp3', uri: 'content://media/1');
const _file = AdhanSoundChoice(SoundKind.file,
    label: 'fajr.mp3', path: '/a/file_fajr_1.mp3', uri: 'content://media/2');

void main() {
  group('AdhanSounds', () {
    test('defaults: system tone, Fajr follows the rest', () {
      const s = AdhanSounds();
      expect(s.uriFor(fajr: false), isNull);
      expect(s.uriFor(fajr: true), isNull);
      expect(s.labelFor(fajr: false), 'نغمة الإشعار الافتراضية');
      expect(s.labelFor(fajr: true), 'نفس صوت الأذان');
    });

    test('Fajr "same" plays the other prayers\' sound', () {
      const s = AdhanSounds(all: _makkah);
      expect(s.uriFor(fajr: false), 'content://media/1');
      expect(s.uriFor(fajr: true), 'content://media/1');
    });

    test('Fajr can have its own sound, or the default tone', () {
      expect(const AdhanSounds(all: _makkah, fajr: _file).uriFor(fajr: true), 'content://media/2');
      expect(
          const AdhanSounds(all: _makkah, fajr: AdhanSoundChoice.system).uriFor(fajr: true),
          isNull);
    });

    test('a choice without a uri falls back to the default tone', () {
      const broken = AdhanSoundChoice(SoundKind.catalog, id: 'x', label: 'x');
      expect(const AdhanSounds(all: broken).uriFor(fajr: false), isNull);
    });

    test('copyWith replaces one side only; usedUris lists both', () {
      final s = const AdhanSounds(all: _makkah).copyWith(fajr: true, choice: _file);
      expect(s.all, _makkah);
      expect(s.fajr, _file);
      expect(s.usedUris, {'content://media/1', 'content://media/2'});
    });

    test('labels', () {
      const s = AdhanSounds(all: _makkah, fajr: _file);
      expect(s.labelFor(fajr: false), 'أذان الحرم المكي');
      expect(s.labelFor(fajr: true), 'ملف من هاتفك · fajr.mp3');
    });

    test('choice JSON round-trips; junk falls back', () {
      final back = AdhanSoundChoice.fromJson(
          jsonDecode(jsonEncode(_makkah.toJson())), AdhanSoundChoice.system);
      expect(back, _makkah);
      expect(back.label, 'أذان الحرم المكي');
      expect(AdhanSoundChoice.fromJson({'kind': 'nope'}, AdhanSoundChoice.same),
          AdhanSoundChoice.same);
      expect(AdhanSoundChoice.fromJson('x', AdhanSoundChoice.system), AdhanSoundChoice.system);
    });
  });

  group('adhan channel ids', () {
    test('default tone keeps the original channel', () {
      expect(Notifications.adhanChannelFor(null), Notifications.adhanChannelId);
    });

    test('one stable channel per sound', () {
      final a = Notifications.adhanChannelFor('content://media/1');
      expect(a, Notifications.adhanChannelFor('content://media/1'));
      expect(a, isNot(Notifications.adhanChannelFor('content://media/2')));
      expect(a, startsWith('prayer_adhan_'));
      expect(a, isNot(Notifications.adhanChannelId));
    });
  });

  group('AdhanCatalog.parse', () {
    test('reads items and skips bad ones', () {
      final items = AdhanCatalog.parse(jsonEncode({
        'version': 1,
        'items': [
          {
            'id': 'makkah',
            'name': 'أذان الحرم المكي',
            'place': 'مكة المكرمة',
            'url': 'https://example.com/makkah.mp3',
            'size': 1468000,
            'seconds': 192,
            'fajrUrl': 'https://example.com/makkah_fajr.mp3',
            'fajrSize': 1530000,
            'credit': 'ejaz215 · CC BY 3.0',
          },
          {'id': 'refaat', 'name': 'محمد رفعت', 'url': 'https://example.com/r.mp3'},
          {'id': 'Bad Id', 'name': 'x', 'url': 'https://example.com/x.mp3'},
          {'id': 'noname', 'url': 'https://example.com/x.mp3'},
          {'id': 'js', 'name': 'x', 'url': 'javascript:alert(1)'},
          'not a map',
        ],
      }));
      expect(items.map((e) => e.id), ['makkah', 'refaat']);
      final m = items.first;
      expect(m.duration, '3:12');
      expect(m.hasFajr, isTrue);
      expect(m.urlFor(fajr: true), 'https://example.com/makkah_fajr.mp3');
      expect(m.sizeFor(fajr: true), 1530000);
      expect(m.credit, 'ejaz215 · CC BY 3.0');
      final r = items.last;
      expect(r.hasFajr, isFalse);
      expect(r.urlFor(fajr: true), 'https://example.com/r.mp3');
      expect(r.place, '');
      expect(r.credit, isNull);
    });

    test('the shipped catalog parses', () {
      expect(AdhanCatalog.parse('{"version":1,"items":[]}'), isEmpty);
    });

    test('a body without items is an error', () {
      expect(() => AdhanCatalog.parse('{"version":1}'), throwsFormatException);
    });
  });
}
