// lib/business/business_models.dart
//
// «Профили тиҷоратӣ» — моделҳо ва дастрасӣ ба сервер
// (backend/handlers/business.go).
import 'dart:convert';

import '../core/api/api_client.dart';

const businessDays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/// Вақти Тоҷикистон: UTC+5, бе соати тобистона.
const tajikistanOffset = Duration(hours: 5);

/// Соатҳои кор: рӯз → фосилаҳо [["09:00","18:00"]].
typedef BusinessHours = Map<String, List<List<String>>>;

BusinessHours parseHours(dynamic raw) {
  final out = <String, List<List<String>>>{};
  if (raw is! Map) return out;
  raw.forEach((k, v) {
    if (v is! List) return;
    out[k.toString()] = [
      for (final iv in v)
        if (iv is List && iv.length == 2) [iv[0].toString(), iv[1].toString()],
    ];
  });
  return out;
}

int _min(String s) {
  final p = s.split(':');
  return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
}

/// Ҳолати «Кушода/Пӯшида» — ҳамон қоидаи сервер (computeOpen).
class OpenState {
  final bool known, open;
  final String closesAt, opensAt, opensDay;
  const OpenState({this.known = false, this.open = false, this.closesAt = '',
      this.opensAt = '', this.opensDay = ''});
}

OpenState computeOpenState(BusinessHours h, DateTime now) {
  if (h.isEmpty) return const OpenState();
  final t = now.toUtc().add(tajikistanOffset);
  final di = t.weekday - 1; // 0 = душанбе
  final cur = t.hour * 60 + t.minute;
  for (final iv in h[businessDays[(di + 6) % 7]] ?? const <List<String>>[]) {
    final o = _min(iv[0]), c = _min(iv[1]);
    if (c < o && cur < c) return OpenState(known: true, open: true, closesAt: iv[1]);
  }
  for (final iv in h[businessDays[di]] ?? const <List<String>>[]) {
    final o = _min(iv[0]), c = _min(iv[1]);
    if (c < o) {
      if (cur >= o) return OpenState(known: true, open: true, closesAt: iv[1]);
      continue;
    }
    if (cur >= o && cur < c) {
      return OpenState(known: true, open: true,
          closesAt: iv[1] == '24:00' ? '00:00' : iv[1]);
    }
  }
  for (var add = 0; add < 8; add++) {
    final day = businessDays[(di + add) % 7];
    final list = [...?h[day]]..sort((a, b) => a[0].compareTo(b[0]));
    for (final iv in list) {
      if (add == 0 && _min(iv[0]) <= cur) continue;
      return OpenState(known: true, opensAt: iv[0], opensDay: day);
    }
  }
  return const OpenState(known: true);
}

class BusinessProfile {
  final String userId, username, avatar, fullName;
  final String category, categoryLabel, address, phone, whatsapp;
  final String placeId, placeName, cityName;
  final BusinessHours hours;
  final int priceRange, productsCount;
  final bool showChat, enabled, isMine;
  final double? lat, lon;
  final OpenState serverOpen;

  const BusinessProfile({
    this.userId = '', this.username = '', this.avatar = '', this.fullName = '',
    this.category = '', this.categoryLabel = '', this.address = '',
    this.phone = '', this.whatsapp = '', this.placeId = '', this.placeName = '',
    this.cityName = '', this.hours = const {}, this.priceRange = 0,
    this.productsCount = 0, this.showChat = true, this.enabled = false,
    this.isMine = false, this.lat, this.lon, this.serverOpen = const OpenState(),
  });

  /// Ҳолати ҳозира (дар телефон аз нав ҳисоб мешавад, то саҳифаи
  /// кушодамонда «Кушода» нагӯяд, вақте ки аллакай пӯшида аст).
  OpenState openAt(DateTime now) => computeOpenState(hours, now);

  static double? _d(Object? v) => v is num ? v.toDouble() : null;

  factory BusinessProfile.fromJson(Map<String, dynamic> j) {
    final place = (j['place'] as Map?)?.cast<String, dynamic>();
    final city = (j['city'] as Map?)?.cast<String, dynamic>();
    return BusinessProfile(
      userId: (j['userId'] ?? '').toString(),
      username: (j['username'] ?? '').toString(),
      avatar: (j['avatar'] ?? '').toString(),
      fullName: (j['fullName'] ?? '').toString(),
      category: (j['category'] ?? '').toString(),
      categoryLabel: (j['categoryLabel'] ?? '').toString(),
      address: (j['address'] ?? '').toString(),
      phone: (j['phone'] ?? '').toString(),
      whatsapp: (j['whatsapp'] ?? '').toString(),
      placeId: (place?['id'] ?? '').toString(),
      placeName: (place?['name'] ?? '').toString(),
      cityName: (city?['name'] ?? '').toString(),
      hours: parseHours(j['hours']),
      priceRange: (j['priceRange'] as num?)?.toInt() ?? 0,
      productsCount: (j['productsCount'] as num?)?.toInt() ?? 0,
      showChat: j['showChat'] != false,
      enabled: j['enabled'] == true,
      isMine: j['isMine'] == true,
      lat: _d(j['lat']),
      lon: _d(j['lon']),
      serverOpen: OpenState(
        known: j['hoursKnown'] == true, open: j['openNow'] == true,
        closesAt: (j['closesAt'] ?? '').toString(),
        opensAt: (j['opensAt'] ?? '').toString(),
        opensDay: (j['opensDay'] ?? '').toString(),
      ),
    );
  }

  /// URI-и «Роҳ» (geo:), бо ном барои харита.
  Uri? get directionsUri {
    if (lat == null || lon == null) return null;
    final label = Uri.encodeComponent(address.isNotEmpty ? address : username);
    return Uri.parse('geo:$lat,$lon?q=$lat,$lon($label)');
  }

  /// Линки WhatsApp (рақам бе «+»).
  Uri? get whatsappUri => whatsapp.isEmpty
      ? null
      : Uri.parse('https://wa.me/${whatsapp.replaceAll(RegExp(r'[^0-9]'), '')}');

  Uri? get phoneUri => phone.isEmpty ? null : Uri.parse('tel:$phone');

  String get priceLabel => priceRange <= 0 ? '' : '\$' * priceRange;
}

class BusinessCategory {
  final String id, label;
  const BusinessCategory(this.id, this.label);
}

class BusinessInsights {
  final int days, visits, uniqueVisitors;
  final Map<String, int> taps;
  final List<(String, int, int)> daily; // (сана, боздид, пахш)
  const BusinessInsights({this.days = 7, this.visits = 0, this.uniqueVisitors = 0,
      this.taps = const {}, this.daily = const []});

  factory BusinessInsights.fromJson(Map<String, dynamic> j) {
    final t = (j['taps'] as Map?)?.cast<String, dynamic>() ?? const {};
    return BusinessInsights(
      days: (j['days'] as num?)?.toInt() ?? 7,
      visits: (j['visits'] as num?)?.toInt() ?? 0,
      uniqueVisitors: (j['uniqueVisitors'] as num?)?.toInt() ?? 0,
      taps: t.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0)),
      daily: [
        for (final d in (j['daily'] as List?) ?? const [])
          if (d is Map)
            ((d['date'] ?? '').toString(), (d['visits'] as num?)?.toInt() ?? 0,
                (d['taps'] as num?)?.toInt() ?? 0),
      ],
    );
  }
}

class BusinessError implements Exception {
  final int status;
  final String code, message;
  const BusinessError(this.status, this.code, this.message);
  @override
  String toString() => message;
}

BusinessError _err(int s, String body) {
  try {
    final j = jsonDecode(body) as Map<String, dynamic>;
    return BusinessError(s, (j['code'] ?? '').toString(), (j['message'] ?? '').toString());
  } catch (_) {
    return BusinessError(s, '', '');
  }
}

class BusinessRepository {
  const BusinessRepository();

  Map<String, dynamic> _json(String b) => jsonDecode(b) as Map<String, dynamic>;

  Future<BusinessProfile?> forUser(String userId, {String lang = 'tj'}) async {
    final r = await ApiClient.instance.get('/business/$userId', query: {'lang': lang});
    if (r.statusCode == 404) return null;
    if (r.statusCode >= 400) throw _err(r.statusCode, r.body);
    return BusinessProfile.fromJson(_json(r.body));
  }

  Future<void> tap(String userId, String action) async {
    try {
      await ApiClient.instance.post('/business/$userId/tap', body: {'action': action});
    } catch (_) {/* омор ихтиёрист */}
  }

  Future<BusinessProfile> mine({String lang = 'tj'}) async {
    final r = await ApiClient.instance.get('/business/me', query: {'lang': lang});
    if (r.statusCode >= 400) throw _err(r.statusCode, r.body);
    return BusinessProfile.fromJson(_json(r.body));
  }

  Future<BusinessProfile> save(Map<String, dynamic> body) async {
    final r = await ApiClient.instance.put('/business/me', body: body);
    if (r.statusCode >= 400) throw _err(r.statusCode, r.body);
    return BusinessProfile.fromJson(_json(r.body));
  }

  Future<void> disable() async {
    final r = await ApiClient.instance.delete('/business/me');
    if (r.statusCode >= 400) throw _err(r.statusCode, r.body);
  }

  Future<BusinessInsights> insights({int days = 7}) async {
    final r = await ApiClient.instance.get('/business/me/insights', query: {'days': '$days'});
    if (r.statusCode >= 400) throw _err(r.statusCode, r.body);
    return BusinessInsights.fromJson(_json(r.body));
  }

  Future<List<BusinessCategory>> categories({String lang = 'tj'}) async {
    final r = await ApiClient.instance.get('/business/categories', query: {'lang': lang});
    if (r.statusCode >= 400) throw _err(r.statusCode, r.body);
    return [
      for (final c in (_json(r.body)['categories'] as List?) ?? const [])
        if (c is Map) BusinessCategory(c['id'].toString(), c['label'].toString()),
    ];
  }

  Future<List<BusinessProfile>> search({String category = '', String city = '',
      String q = '', String lang = 'tj', int page = 1}) async {
    final r = await ApiClient.instance.get('/business/search', query: {
      if (category.isNotEmpty) 'category': category,
      if (city.isNotEmpty) 'city': city,
      if (q.isNotEmpty) 'q': q,
      'lang': lang, 'page': '$page',
    });
    if (r.statusCode >= 400) throw _err(r.statusCode, r.body);
    return [
      for (final b in (_json(r.body)['items'] as List?) ?? const [])
        if (b is Map) BusinessProfile.fromJson(b.cast<String, dynamic>()),
    ];
  }
}
