import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

import 'place.dart';
import 'place_normalize.dart';

/// Рӯйхати офлайни ҷойҳои Тоҷикистон (assets/places/places_tj.json).
///
/// Танҳо вақте истифода мешавад, ки сервер дастрас нест. Тартиб ҳамон
/// аст, ки дар backend/places/places.go: пурра > аз сар > аз сари калима
/// > дар мобайн; баъд аҳамият ва наздикӣ.
class PlacesOffline {
  final List<_Entry> _entries;
  final Map<String, _Entry> _byId;

  PlacesOffline._(this._entries)
      : _byId = {for (final e in _entries) e.id: e};

  static PlacesOffline? _cached;

  /// Аз asset бор мекунад (як бор).
  static Future<PlacesOffline> load() async {
    final c = _cached;
    if (c != null) return c;
    final raw = await rootBundle.loadString('assets/places/places_tj.json');
    return _cached = PlacesOffline.fromJsonString(raw);
  }

  factory PlacesOffline.fromJsonString(String raw) {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final list = (data['places'] as List? ?? [])
        .whereType<Map>()
        .map((m) => _Entry.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    return PlacesOffline._(list);
  }

  int get length => _entries.length;

  Place _toPlace(_Entry e, {double? dist}) {
    final parts = <String>[];
    var cur = _byId[e.parent];
    for (var i = 0; cur != null && i < 2; i++) {
      parts.add(cur.tj);
      cur = _byId[cur.parent];
    }
    return Place(
      id: e.id,
      name: e.tj,
      region: parts.join(', '),
      kind: e.kind,
      lat: e.lat,
      lon: e.lon,
      distanceKm: dist,
    );
  }

  static int _tier(List<String> keys, String q) {
    var best = 0;
    for (final k in keys) {
      var t = 0;
      if (k == q) {
        t = 1000;
      } else if (k.startsWith(q)) {
        t = 800;
      } else if (k.contains(' $q')) {
        t = 600;
      } else if (q.length >= 3 && k.contains(q)) {
        t = 400;
      }
      if (t > best) best = t;
    }
    return best;
  }

  List<Place> search(String query, {double? lat, double? lon, int limit = 20}) {
    final q = normalizePlace(query);
    final hasLoc = lat != null && lon != null;
    if (q.isEmpty) {
      if (hasLoc) return nearest(lat, lon).nearby.take(limit).toList();
      final cities = _entries.where((e) => e.kind == 'city').toList()
        ..sort((a, b) => b.weight.compareTo(a.weight));
      return cities.take(limit).map(_toPlace).toList();
    }
    final scored = <MapEntry<double, Place>>[];
    for (final e in _entries) {
      final t = _tier(e.keys, q);
      if (t == 0) continue;
      double score = (t + e.weight).toDouble();
      double? d;
      if (hasLoc) {
        d = distanceKm(lat, lon, e.lat, e.lon);
        score += 95 * math.exp(-d / 50);
      }
      scored.add(MapEntry(score, _toPlace(e, dist: d)));
    }
    scored.sort((a, b) {
      final c = b.key.compareTo(a.key);
      return c != 0 ? c : a.value.id.compareTo(b.value.id);
    });
    return scored.take(limit).map((e) => e.value).toList();
  }

  static double _radius(_Entry e) {
    if (e.kind != 'city') return 0;
    if (e.id == 'tj-dushanbe') return 12;
    return e.weight >= 82 ? 6 : 3;
  }

  NearestResult nearest(double lat, double lon) {
    final list = <MapEntry<double, _Entry>>[];
    for (final e in _entries) {
      if (!const {'city', 'district', 'town', 'poi'}.contains(e.kind)) continue;
      final d = distanceKm(lat, lon, e.lat, e.lon);
      if (d > 300) continue;
      list.add(MapEntry(d, e));
    }
    list.sort((a, b) =>
        (a.key - _radius(a.value)).compareTo(b.key - _radius(b.value)));
    MapEntry<double, _Entry>? best;
    for (final m in list) {
      if (m.value.kind == 'poi') continue;
      best = m;
      break;
    }
    final place = (best != null && best.key <= 150 + _radius(best.value))
        ? _toPlace(best.value, dist: best.key)
        : null;
    return NearestResult(
      place: place,
      nearby: list.take(15).map((m) => _toPlace(m.value, dist: m.key)).toList(),
    );
  }

  static double distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    const rad = math.pi / 180;
    final dLat = (lat2 - lat1) * rad;
    final dLon = (lon2 - lon1) * rad;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * rad) *
            math.cos(lat2 * rad) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * r * math.asin(math.min(1, math.sqrt(a)));
  }
}

class _Entry {
  final String id, kind, parent, tj;
  final double lat, lon;
  final int weight;
  final List<String> keys;

  _Entry(this.id, this.kind, this.parent, this.tj, this.lat, this.lon,
      this.weight, this.keys);

  factory _Entry.fromJson(Map<String, dynamic> j) {
    final names = <String>[
      (j['tj'] ?? '').toString(),
      (j['ru'] ?? '').toString(),
      (j['en'] ?? '').toString(),
      ...(j['a'] as List? ?? []).map((e) => e.toString()),
    ];
    final keys = <String>{};
    for (final n in names) {
      final k = normalizePlace(n);
      if (k.isNotEmpty) keys.add(k);
    }
    return _Entry(
      (j['id'] ?? '').toString(),
      (j['k'] ?? '').toString(),
      (j['p'] ?? '').toString(),
      (j['tj'] ?? '').toString(),
      (j['lat'] as num?)?.toDouble() ?? 0,
      (j['lon'] as num?)?.toDouble() ?? 0,
      (j['w'] as num?)?.toInt() ?? 0,
      keys.toList(),
    );
  }
}
