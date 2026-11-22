import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One downloadable voice. [fajrUrl] is an optional Fajr recording (with
/// "الصلاة خير من النوم"); without it Fajr uses [url] too.
class AdhanCatalogItem {
  final String id;
  final String name;
  final String place;
  final String url;
  final int size;
  final int seconds;
  final String? fajrUrl;
  final int fajrSize;

  /// Author and license, shown under the voice (CC BY / BY-SA require it).
  final String? credit;

  const AdhanCatalogItem({
    required this.id,
    required this.name,
    required this.place,
    required this.url,
    this.size = 0,
    this.seconds = 0,
    this.fajrUrl,
    this.fajrSize = 0,
    this.credit,
  });

  bool get hasFajr => fajrUrl != null;
  String urlFor({required bool fajr}) => fajr && hasFajr ? fajrUrl! : url;
  int sizeFor({required bool fajr}) => fajr && hasFajr ? fajrSize : size;

  /// "3:12"
  String get duration =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  static final _idPattern = RegExp(r'^[a-z0-9_-]{1,40}$');

  /// Null for an entry that is missing fields or points somewhere odd, so
  /// one bad line in the catalog never breaks the list.
  static AdhanCatalogItem? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], name = j['name'], url = j['url'];
    if (id is! String || !_idPattern.hasMatch(id)) return null;
    if (name is! String || name.isEmpty || !_okUrl(url)) return null;
    final fajrUrl = j['fajrUrl'];
    return AdhanCatalogItem(
      id: id,
      name: name,
      place: j['place'] is String ? j['place'] as String : '',
      url: url as String,
      size: j['size'] is int ? j['size'] as int : 0,
      seconds: j['seconds'] is int ? j['seconds'] as int : 0,
      fajrUrl: _okUrl(fajrUrl) ? fajrUrl as String : null,
      fajrSize: j['fajrSize'] is int ? j['fajrSize'] as int : 0,
      credit: j['credit'] is String && (j['credit'] as String).isNotEmpty
          ? j['credit'] as String
          : null,
    );
  }

  static bool _okUrl(Object? u) {
    if (u is! String) return false;
    final uri = Uri.tryParse(u);
    if (uri == null || uri.host.isEmpty) return false;
    // plain http only for a local test catalog in debug builds
    return uri.scheme == 'https' || (kDebugMode && uri.scheme == 'http');
  }
}

/// The voice list lives in the repo (adhan/catalog.json), so a voice is
/// added or removed without an app update. The last good copy is cached
/// for offline use.
class AdhanCatalog {
  static const url = String.fromEnvironment(
    'ADHAN_CATALOG_URL',
    defaultValue:
        'https://raw.githubusercontent.com/ahmedtaher3/quran-app/main/adhan/catalog.json',
  );
  static const _cacheKey = 'adhan_catalog_cache';

  static List<AdhanCatalogItem> parse(String body) {
    final j = jsonDecode(body);
    final items = j is Map ? j['items'] : null;
    if (items is! List) throw const FormatException('no items');
    return items.map(AdhanCatalogItem.fromJson).whereType<AdhanCatalogItem>().toList();
  }

  static Future<List<AdhanCatalogItem>> cached() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cacheKey);
    if (raw == null) return const [];
    try {
      return parse(raw);
    } catch (_) {
      return const [];
    }
  }

  /// Fresh list from the network; throws when offline or malformed.
  static Future<List<AdhanCatalogItem>> fetch() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close().timeout(const Duration(seconds: 15));
      final p = await SharedPreferences.getInstance();
      if (res.statusCode == 404) {
        // no catalog published (or it was taken down): no voices, which is
        // not an error, and the cached list must not linger
        await res.drain<void>();
        await p.setString(_cacheKey, '{"items":[]}');
        return const [];
      }
      if (res.statusCode != 200) throw HttpException('${res.statusCode}');
      final body = await res.transform(utf8.decoder).join();
      final items = parse(body);
      await p.setString(_cacheKey, body);
      return items;
    } finally {
      client.close();
    }
  }
}
