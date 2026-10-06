import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_settings.dart';
import '../api/api_client.dart';
import 'place.dart';
import 'places_offline.dart';

/// Натиҷаи ҷустуҷӯ. [offline] — сервер ҷавоб надод ва рӯйхати дохилии
/// Тоҷикистон истифода шуд.
class PlaceSearchResult {
  final List<Place> places;
  final bool offline;
  const PlaceSearchResult(this.places, {this.offline = false});
}

/// Манбаи ҷойҳо (дар тестҳо иваз карда мешавад).
abstract class PlacesSource {
  Future<PlaceSearchResult> search(String query, {double? lat, double? lon});
  Future<NearestResult> nearest(double lat, double lon);
}

/// Аввал сервер (GET /places/search, /places/nearest) — рӯйхатро бе
/// навсозии барнома беҳтар кардан мумкин аст; агар сервер дастрас
/// набошад — рӯйхати дохилии Тоҷикистон.
///
/// Махфият: координатаҳо пеш аз фиристодан мудаввар мешаванд (~1 км
/// барои «Ҷойи ҳозира», ~10 км барои тартиби ҷустуҷӯ) ва ба сервери худи
/// мо мераванд, на ба хидмати берунӣ.
class PlacesRepository implements PlacesSource {
  PlacesRepository({Future<PlacesOffline> Function()? offline})
      : _offline = offline ?? PlacesOffline.load;

  static final PlacesRepository instance = PlacesRepository();

  final Future<PlacesOffline> Function() _offline;
  static const _timeout = Duration(seconds: 6);

  String get _lang => AppSettingsState.instance.lang;

  static String _round(double v, int digits) => v.toStringAsFixed(digits);

  @override
  Future<PlaceSearchResult> search(String query,
      {double? lat, double? lon}) async {
    try {
      final res = await ApiClient.instance.get('/places/search', query: {
        'q': query,
        'lang': _lang,
        'limit': '30',
        if (lat != null && lon != null) ...{
          'lat': _round(lat, 1),
          'lon': _round(lon, 1),
        },
      }).timeout(_timeout);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return PlaceSearchResult(_list(body['places']));
      }
    } catch (_) {}
    final off = await _offline();
    return PlaceSearchResult(off.search(query, lat: lat, lon: lon),
        offline: true);
  }

  @override
  Future<NearestResult> nearest(double lat, double lon) async {
    try {
      final res = await ApiClient.instance.get('/places/nearest', query: {
        'lat': _round(lat, 2),
        'lon': _round(lon, 2),
        'lang': _lang,
      }).timeout(_timeout);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final p = body['place'];
        return NearestResult(
          place: p is Map ? Place.fromJson(Map<String, dynamic>.from(p)) : null,
          nearby: _list(body['nearby']),
        );
      }
    } catch (_) {}
    return (await _offline()).nearest(lat, lon);
  }

  static List<Place> _list(Object? v) => (v as List? ?? [])
      .whereType<Map>()
      .map((m) => Place.fromJson(Map<String, dynamic>.from(m)))
      .where((p) => p.name.isNotEmpty)
      .toList();
}

/// Ҷойҳои охирин интихобшуда (танҳо дар ҳамин телефон).
class PlaceRecents {
  PlaceRecents._();
  static final PlaceRecents instance = PlaceRecents._();

  static const _key = 'places.recent.v1';
  static const max = 8;

  Future<List<Place>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_key) ?? [])
          .map((s) {
            try {
              return Place.fromJson(jsonDecode(s) as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<Place>()
          .where((p) => p.name.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> add(Place p) async {
    if (p.name.isEmpty) return;
    try {
      final list = (await load()).where((x) => x != p).toList();
      list.insert(0, p);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          _key, list.take(max).map((e) => jsonEncode(e.toJson())).toList());
    } catch (_) {}
  }
}
