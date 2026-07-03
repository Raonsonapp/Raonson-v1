// lib/effects/effects_repository.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';

class EffectItem {
  final String id, name;
  final List<double> matrix;
  final double price;
  final int downloads;
  final String creatorId, creatorName, creatorAvatar;
  final bool creatorVerified;
  EffectItem({
    required this.id, required this.name, required this.matrix,
    required this.price, required this.downloads,
    required this.creatorId, required this.creatorName,
    required this.creatorAvatar, required this.creatorVerified,
  });
  bool get isPremium => price > 0;
  factory EffectItem.fromJson(Map<String, dynamic> j) {
    final c = (j['creator'] ?? {}) as Map;
    final m = (j['matrix'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        const <double>[];
    return EffectItem(
      id: (j['_id'] ?? j['id'] ?? '').toString(),
      name: (j['name'] ?? 'Эффект').toString(),
      matrix: m.length == 20 ? m : _identity,
      price: (j['price'] as num?)?.toDouble() ?? 0,
      downloads: (j['downloads'] as num?)?.toInt() ?? 0,
      creatorId: (c['_id'] ?? c['id'] ?? '').toString(),
      creatorName: (c['username'] ?? '').toString(),
      creatorAvatar: (c['avatar'] ?? '').toString(),
      creatorVerified: c['verified'] == true,
    );
  }
  static const _identity = [
    1.0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0
  ];
}

class EffectsRepository {
  final _api = ApiClient.instance;
  static const _kSaved = 'saved_effects';

  Future<List<EffectItem>> getEffects() async {
    try {
      final r = await _api.get('/effects/');
      if (r.statusCode >= 400) return [];
      final body = jsonDecode(r.body);
      final list = (body['effects'] ?? []) as List;
      return list
          .map((e) => EffectItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> createEffect(
      String name, List<double> matrix, double price) async {
    try {
      final r = await _api.post('/effects/',
          body: {'name': name, 'matrix': matrix, 'price': price});
      return r.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  Future<bool> useEffect(String id) async {
    try {
      final r = await _api.post('/effects/$id/use');
      return r.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  // ── Локалӣ: эффектҳои «истифодашуда» → дар таҳриргари пост пайдо мешаванд.
  Future<void> saveLocally(String name, List<double> matrix) async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getStringList(_kSaved) ?? [];
      raw.add(jsonEncode({'name': name, 'matrix': matrix}));
      // ниг. дошт ба ҳадди 30-то
      final trimmed = raw.length > 30 ? raw.sublist(raw.length - 30) : raw;
      await p.setStringList(_kSaved, trimmed);
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> loadSaved() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getStringList(_kSaved) ?? [];
      return raw
          .map((e) => jsonDecode(e) as Map<String, dynamic>)
          .where((m) => (m['matrix'] as List?)?.length == 20)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
