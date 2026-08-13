import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/reel_model.dart';

class ReelsRepository {
  final ApiClient _api;
  ReelsRepository(this._api);

  // ── Cache ─────────────────────────────────────────────────────
  static List<ReelModel>? _memCache;
  static DateTime?        _memCacheTime;
  static const _memCacheTTL  = Duration(minutes: 10);
  static const _diskCacheKey = 'reels_cache_v2';
  static const _diskCacheTTL = Duration(hours: 48);

  bool get _memCacheValid =>
      _memCache != null &&
      _memCacheTime != null &&
      DateTime.now().difference(_memCacheTime!) < _memCacheTTL;

  Future<void> _saveToDisk(List<ReelModel> reels) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = {
        'time': DateTime.now().millisecondsSinceEpoch,
        'reels': reels.map((r) => r.toJson()).toList(),
      };
      await prefs.setString(_diskCacheKey, jsonEncode(payload));
    } catch (_) {}
  }

  Future<List<ReelModel>?> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_diskCacheKey);
      if (raw == null) return null;
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final time = payload['time'] as int;
      final age  = DateTime.now().millisecondsSinceEpoch - time;
      if (age > _diskCacheTTL.inMilliseconds) return null;
      final list = payload['reels'] as List;
      return list
          .map((e) => ReelModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) { return null; }
  }

  // ✅ МУШКИЛИ АСОСӢ ИСЛОҲ ШУД:
  // Page 1 → аввал кэш, баъд network background-да
  Future<List<ReelModel>> fetchReels({
    int page = 1, int limit = 20, bool smart = true,
    bool friends = false}) async {

    // ── Page 1: cache аввал (кэш танҳо барои лентаи умумӣ) ───────
    if (page == 1 && !friends) {
      if (_memCacheValid) return _memCache!;

      final disk = await _loadFromDisk();
      if (disk != null && disk.isNotEmpty) {
        _memCache     = disk;
        _memCacheTime = DateTime.now();
        // Background-да yangi reels
        _refreshInBackground(limit: limit, smart: smart);
        return disk; // ← ФАВРАН!
      }
    }

    // ── Network ──────────────────────────────────────────────────
    try {
      if (smart && !friends) {
        try {
          final res = await _api.get('/reels/smart',
              query: {'page': '$page', 'limit': '$limit'})
              .timeout(const Duration(seconds: 8));

          if (res.statusCode == 200) {
            final reels = _parse(jsonDecode(res.body));
            if (page == 1) {
              _memCache     = reels;
              _memCacheTime = DateTime.now();
              _saveToDisk(reels);
            }
            return reels;
          }
          if (res.statusCode == 401) throw Exception('Unauthorized');
        } catch (e) {
          if (e.toString().contains('Unauthorized')) rethrow;
          // Smart feed нест → одди
        }
      }

      final res = await _api.get(ApiEndpoints.reels,
          query: {'page': '$page', 'limit': '$limit',
            if (friends) 'friends': '1'})
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 401) throw Exception('Unauthorized');
      if (res.statusCode >= 400) throw Exception('Server ${res.statusCode}');

      final reels = _parse(jsonDecode(res.body));
      if (page == 1 && !friends) {
        _memCache     = reels;
        _memCacheTime = DateTime.now();
        _saveToDisk(reels);
      }
      return reels;

    } catch (e) {
      if (e.toString().contains('Unauthorized')) rethrow;
      // ✅ Хато → кэш нишон деҳ
      if (page == 1 && !friends) {
        if (_memCache != null && _memCache!.isNotEmpty) return _memCache!;
        final disk = await _loadFromDisk();
        if (disk != null && disk.isNotEmpty) return disk;
      }
      rethrow;
    }
  }

  void _refreshInBackground({int limit = 20, bool smart = true}) {
    Future.delayed(const Duration(seconds: 1), () async {
      try {
        final endpoint = smart ? '/reels/smart' : ApiEndpoints.reels;
        final res = await _api.get(endpoint,
            query: {'page': '1', 'limit': '$limit'})
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final reels = _parse(jsonDecode(res.body));
          if (reels.isNotEmpty) {
            _memCache     = reels;
            _memCacheTime = DateTime.now();
            _saveToDisk(reels);
          }
        }
      } catch (_) {}
    });
  }

  List<ReelModel> _parse(dynamic body) {
    final List list = body is Map
        ? (body['reels'] ?? body['data'] ?? []) : body as List;
    return list.map((e) =>
        ReelModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>?> likeReel(String reelId) async {
    try {
      final res = await _api.post('${ApiEndpoints.reels}/$reelId/like');
      if (res.statusCode < 400) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<void> saveReel(String reelId) async {
    try { await _api.post('${ApiEndpoints.reels}/$reelId/save'); } catch (_) {}
  }

  Future<void> trackWatchTime({
    required String reelId,
    required int    watchMs,
    required int    durationMs,
  }) async {
    try {
      // POST /reels/:id/watch — калидҳо ДАҚИҚ мувофиқи backend: watchMs, completed.
      await _api.post('${ApiEndpoints.reels}/$reelId/watch', body: {
        'watchMs':   watchMs,
        'completed': durationMs > 0 && watchMs >= (durationMs * 0.9).round(),
      }).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<void> markNotInterested(String reelId) async {
    try { await _api.post('${ApiEndpoints.reels}/$reelId/not_interest'); }
    catch (_) {}
  }

  Future<Map<String, dynamic>?> fetchStats(String reelId) async {
    try {
      final res = await _api.get('${ApiEndpoints.reels}/$reelId/stats')
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchComments(String reelId) async {
    try {
      final res = await _api.get('${ApiEndpoints.reels}/$reelId/comments')
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List list = body is Map ? (body['comments'] ?? []) : body as List;
        return list.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  Future<void> addComment({required String reelId, required String text}) async {
    final res = await _api.post('${ApiEndpoints.reels}/$reelId/comments',
        body: {'text': text});
    if (res.statusCode >= 400) throw Exception('Comment failed');
  }

  Future<void> replyComment({
    required String reelId,
    required String commentId,
    required String text,
  }) async {
    final res = await _api.post('${ApiEndpoints.reels}/$reelId/comments/$commentId/reply',
        body: {'text': text});
    if (res.statusCode >= 400) throw Exception('Reply failed');
  }

  Future<Map<String, dynamic>?> likeComment({
    required String reelId,
    required String commentId,
  }) async {
    try {
      final res = await _api.post(
          '${ApiEndpoints.reels}/$reelId/comments/$commentId/like');
      if (res.statusCode < 400) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }
}
