// lib/core/storage/offline_cache.dart
//
// Кэши офлайн барои экранҳои асосӣ — мисли Instagram/Telegram: бе
// интернет ё бо интернети суст маълумоти ОХИРИН нишон дода мешавад,
// на экрани хато ё «Паёме нест».
//
// Қоидаҳо:
//  • Калид ба корбари воридшуда баста аст (`oc1:<userId>:<name>`) — лента,
//    чатҳо ва профилҳои як аккаунт ба аккаунти дигар намерасанд.
//  • Кэш барои нишон додан «куҳна» намешавад (то [defaultMaxAge]): беҳтар
//    маълумоти дирӯза аз экрани холӣ. Навсозӣ ҳамеша аз шабака меояд.
//  • Андоза маҳдуд аст: рӯйхатҳо то [maxItems] бурида мешаванд ва
//    гурӯҳҳо (масалан профилҳои дидашуда) то [groupMax] калид нигоҳ
//    медоранд — SharedPreferences дар Android як файл аст.
import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/user_session.dart';

class CachedValue {
  final dynamic data;
  final DateTime savedAt;
  const CachedValue(this.data, this.savedAt);

  Duration get age => DateTime.now().difference(savedAt);
}

class OfflineCache {
  OfflineCache._();

  static const prefix = 'oc1:';
  static const defaultMaxAge = Duration(days: 30);
  static const defaultMaxItems = 60;

  /// Корбари ҷорӣ; `null` — ҳанӯз ворид нашудааст (кэш истифода намешавад).
  static String? Function() viewerId = () => UserSession.userId;

  static String? _key(String name) {
    final uid = viewerId();
    if (uid == null || uid.isEmpty) return null;
    return '$prefix$uid:$name';
  }

  /// Навиштан. Рӯйхат то [maxItems] бурида мешавад (аз аввал — навтаринҳо).
  ///
  /// [group] — калидҳои ҳамҷинс (масалан `profile`); агар шумораашон аз
  /// [groupMax] гузарад, куҳнатаринҳо нест мешаванд.
  static Future<void> put(String name, dynamic data,
      {int maxItems = defaultMaxItems,
      String? group,
      int groupMax = 40}) async {
    final key = _key(name);
    if (key == null || data == null) return;
    var d = data;
    if (d is List && d.length > maxItems) d = d.sublist(0, maxItems);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode({
        't': DateTime.now().millisecondsSinceEpoch,
        'd': d,
      }));
      if (group != null) await _touchGroup(prefs, group, name, groupMax);
    } catch (_) {
      // Кэш ихтиёрист — хатои диск экранро намешиканад.
    }
  }

  static Future<CachedValue?> get(String name,
      {Duration maxAge = defaultMaxAge}) async {
    final key = _key(name);
    if (key == null) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final saved =
          DateTime.fromMillisecondsSinceEpoch((m['t'] as num).toInt());
      if (DateTime.now().difference(saved) > maxAge) return null;
      return CachedValue(m['d'], saved);
    } catch (_) {
      return null;
    }
  }

  static Future<void> remove(String name) async {
    final key = _key(name);
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }

  /// Кэши як корбар (пешфарз — корбари ҷорӣ), масалан ҳангоми баромадан:
  /// чатҳо ва лентаи ӯ дар телефони муштарак намемонанд.
  static Future<void> clearViewer([String? userId]) async {
    final uid = userId ?? viewerId();
    if (uid == null || uid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in prefs.getKeys().toList()) {
        if (k.startsWith('$prefix$uid:')) await prefs.remove(k);
      }
    } catch (_) {}
  }

  /// Ҳамаи кэши офлайни ҲАМАИ аккаунтҳо (масалан ҳангоми баромадан).
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in prefs.getKeys().toList()) {
        if (k.startsWith(prefix)) await prefs.remove(k);
      }
    } catch (_) {}
  }

  static Future<void> _touchGroup(SharedPreferences prefs, String group,
      String name, int groupMax) async {
    final idxKey = _key('__idx:$group');
    if (idxKey == null) return;
    final list = prefs.getStringList(idxKey) ?? <String>[];
    list
      ..remove(name)
      ..add(name);
    while (list.length > groupMax) {
      final old = list.removeAt(0);
      final k = _key(old);
      if (k != null) await prefs.remove(k);
    }
    await prefs.setStringList(idxKey, list);
  }
}

/// Натиҷаи як боркунии «аввал кэш, баъд шабака».
class CacheFirstOutcome {
  /// Хатои шабака (null — маълумоти нав расид).
  final Object? error;

  /// Дар экран маълумот ҳаст (аз кэш ё аз боркунии қаблӣ).
  final bool hadData;

  const CacheFirstOutcome({this.error, required this.hadData});

  bool get isFresh => error == null;

  /// Шабака нашуд, вале маълумоти охирин нишон дода шудааст →
  /// баннери хурди «Офлайн — маълумоти охирин», на экрани хато.
  bool get isStale => error != null && hadData;

  /// Шабака нашуд ва ҳеҷ чиз барои нишон додан нест → экрани хато.
  bool get isFailed => error != null && !hadData;
}

/// Тартиби ягона барои ҳамаи экранҳо:
///  1. кэш → фавран [onData] (`fromCache: true`), агар [hasData] набошад;
///  2. шабака → [onData] (`fromCache: false`);
///  3. хатои шабака → кэш/маълумоти мавҷуда дар экран мемонад.
///
/// [hasData] — экран аллакай чизе нишон медиҳад (масалан pull-to-refresh);
/// он гоҳ кэш дубора хонда намешавад.
Future<CacheFirstOutcome> loadCacheFirst<T>({
  required Future<T?> Function() readCache,
  required Future<T> Function() fetch,
  required void Function(T data, {required bool fromCache}) onData,
  bool hasData = false,
}) async {
  var had = hasData;
  if (!had) {
    T? cached;
    try {
      cached = await readCache();
    } catch (_) {}
    if (cached != null && !(cached is List && cached.isEmpty)) {
      onData(cached, fromCache: true);
      had = true;
    }
  }
  try {
    final fresh = await fetch();
    onData(fresh, fromCache: false);
    return CacheFirstOutcome(hadData: true);
  } catch (e) {
    return CacheFirstOutcome(error: e, hadData: had);
  }
}
