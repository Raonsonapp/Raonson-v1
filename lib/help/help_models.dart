// lib/help/help_models.dart
//
// «Кӯмаки фаврӣ» — моделҳо ва дастрасӣ ба сервер (backend/handlers/help_board.go).
import 'dart:convert';

import '../core/api/api_client.dart';
import '../core/utils/server_time.dart';
import '../models/user_model.dart';

/// Навъҳои дархост (ҳамон сатрҳое, ки сервер мефаҳмад).
const helpKinds = [
  'blood', 'lost_person', 'lost_pet', 'lost_document', 'found', 'urgent',
];

/// Гурӯҳҳои хун.
const bloodGroups = ['O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+'];

class HelpRequest {
  final String id;
  final String kind;
  final String title;
  final String body;
  final String bloodGroup;
  final int units;
  final String hospital;
  final String cityId;
  final String cityName;
  final String placeName;
  final String photoUrl;
  /// open | resolved | expired | removed
  final String status;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final int responsesCount;
  final bool isMine;
  final bool responded;
  final bool pendingReview;
  final int? notifiedCount;
  final UserModel author;

  const HelpRequest({
    required this.id,
    required this.kind,
    required this.title,
    this.body = '',
    this.bloodGroup = '',
    this.units = 0,
    this.hospital = '',
    this.cityId = '',
    this.cityName = '',
    this.placeName = '',
    this.photoUrl = '',
    this.status = 'open',
    this.expiresAt,
    this.createdAt,
    this.responsesCount = 0,
    this.isMine = false,
    this.responded = false,
    this.pendingReview = false,
    this.notifiedCount,
    required this.author,
  });

  bool get isOpen => status == 'open';
  bool get isBlood => kind == 'blood';

  factory HelpRequest.fromJson(Map<String, dynamic> j) {
    final city = (j['city'] as Map?)?.cast<String, dynamic>() ?? const {};
    final place = (j['place'] as Map?)?.cast<String, dynamic>();
    final u = (j['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    return HelpRequest(
      id: (j['_id'] ?? '').toString(),
      kind: (j['kind'] ?? 'urgent').toString(),
      title: (j['title'] ?? '').toString(),
      body: (j['body'] ?? '').toString(),
      bloodGroup: (j['bloodGroup'] ?? '').toString(),
      units: (j['units'] as num?)?.toInt() ?? 0,
      hospital: (j['hospital'] ?? '').toString(),
      cityId: (city['id'] ?? '').toString(),
      cityName: (city['name'] ?? '').toString(),
      placeName: (place?['name'] ?? '').toString(),
      photoUrl: (j['photoUrl'] ?? '').toString(),
      status: (j['status'] ?? 'open').toString(),
      expiresAt: parseServerTime(j['expiresAt']),
      createdAt: parseServerTime(j['createdAt']),
      responsesCount: (j['responsesCount'] as num?)?.toInt() ?? 0,
      isMine: j['isMine'] == true,
      responded: j['responded'] == true,
      pendingReview: j['pendingReview'] == true,
      notifiedCount: (j['notifiedCount'] as num?)?.toInt(),
      author: UserModel.fromMinJson(u),
    );
  }
}

/// Вақти боқимонда: (рақам, воҳид) — 'h' ё 'd'. null — гузаштааст.
(int, String)? helpTimeLeft(DateTime? expiresAt, {DateTime? now}) {
  if (expiresAt == null) return null;
  final left = expiresAt.difference(now ?? DateTime.now());
  if (left.isNegative) return null;
  if (left.inHours < 48) return (left.inHours < 1 ? 1 : left.inHours, 'h');
  return (left.inDays, 'd');
}

/// Танзимоти донор.
class DonorSettings {
  final bool enabled;
  final String bloodGroup;
  final String cityId;
  final String cityName;
  const DonorSettings({this.enabled = false, this.bloodGroup = '',
      this.cityId = '', this.cityName = ''});

  factory DonorSettings.fromJson(Map<String, dynamic> j) {
    final c = (j['city'] as Map?)?.cast<String, dynamic>() ?? const {};
    return DonorSettings(
      enabled: j['enabled'] == true,
      bloodGroup: (j['bloodGroup'] ?? '').toString(),
      cityId: (c['id'] ?? '').toString(),
      cityName: (c['name'] ?? '').toString(),
    );
  }
}

/// Хатои сервер бо код (help_trust_required, help_daily_cap, …).
class HelpError implements Exception {
  final int status;
  final String code;
  final String message;
  const HelpError(this.status, this.code, this.message);
  @override
  String toString() => message;
}

HelpError _err(int status, String body) {
  try {
    final j = jsonDecode(body) as Map<String, dynamic>;
    return HelpError(status, (j['code'] ?? '').toString(),
        (j['message'] ?? '').toString());
  } catch (_) {
    return HelpError(status, '', '');
  }
}

/// Дастрасӣ ба сервер (дар тест иваз мешавад).
class HelpRepository {
  const HelpRepository();

  Future<List<HelpRequest>> list({String city = '', String kind = '',
      bool mine = false, int page = 1}) async {
    final r = await ApiClient.instance.get('/help', query: {
      if (city.isNotEmpty) 'city': city,
      if (kind.isNotEmpty) 'kind': kind,
      if (mine) 'mine': '1',
      'page': '$page',
    });
    if (r.statusCode >= 400) throw _err(r.statusCode, r.body);
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return ((j['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => HelpRequest.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<HelpRequest> get(String id) async {
    final r = await ApiClient.instance.get('/help/$id');
    if (r.statusCode >= 400) throw _err(r.statusCode, r.body);
    return HelpRequest.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<HelpRequest> create(Map<String, dynamic> body) async {
    final r = await ApiClient.instance.post('/help', body: body);
    if (r.statusCode >= 400) throw _err(r.statusCode, r.body);
    return HelpRequest.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// Ҷавоб медиҳад ва муаллифро (барои чат) бармегардонад.
  Future<UserModel> respond(String id) async {
    final r = await ApiClient.instance.post('/help/$id/respond');
    if (r.statusCode >= 400) throw _err(r.statusCode, r.body);
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return UserModel.fromMinJson(
        (j['author'] as Map?)?.cast<String, dynamic>() ?? const {});
  }

  Future<void> resolve(String id) async {
    final r = await ApiClient.instance.post('/help/$id/resolve');
    if (r.statusCode >= 400) throw _err(r.statusCode, r.body);
  }

  Future<void> remove(String id) async {
    final r = await ApiClient.instance.delete('/help/$id');
    if (r.statusCode >= 400) throw _err(r.statusCode, r.body);
  }

  Future<void> report(String id, String reason) async {
    final r = await ApiClient.instance
        .post('/help/$id/report', body: {'reason': reason});
    if (r.statusCode >= 400) throw _err(r.statusCode, r.body);
  }

  Future<DonorSettings> donor() async {
    final r = await ApiClient.instance.get('/help/donor/me');
    if (r.statusCode >= 400) throw _err(r.statusCode, r.body);
    return DonorSettings.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<DonorSettings> setDonor({required bool enabled, String bloodGroup = '',
      String cityId = ''}) async {
    final r = await ApiClient.instance.put('/help/donor/me', body: {
      'enabled': enabled, 'bloodGroup': bloodGroup, 'cityId': cityId,
    });
    if (r.statusCode >= 400) throw _err(r.statusCode, r.body);
    return DonorSettings.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> deleteDonor() async {
    final r = await ApiClient.instance.delete('/help/donor/me');
    if (r.statusCode >= 400) throw _err(r.statusCode, r.body);
  }
}
