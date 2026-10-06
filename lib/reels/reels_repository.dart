import 'dart:convert';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/storage/offline_cache.dart';
import '../models/reel_model.dart';
import '../core/services/follow_service.dart';

class ReelsRepository {
  final ApiClient _api;
  ReelsRepository(this._api);

  // ── Cache ─────────────────────────────────────────────────────
  static List<ReelModel>? _memCache;
  static DateTime?        _memCacheTime;
  static const _memCacheTTL  = Duration(minutes: 10);
  /// Кэши диск дар [OfflineCache] — ба корбар баста (на як калид барои
  /// ҳамаи аккаунтҳо) ва то 30 рӯз барои офлайн нигоҳ дошта мешавад.
  static const _diskCacheName = 'reels';
  static const _diskCacheMax  = 30;

  /// Натиҷаи охирини [fetchReels] аз кэш буд (на аз шабака).
  bool lastFromCache = false;

  // Пас аз иваз кардани аккаунт: cache-и хотираро тоза мекунем. Кэши
  // диск аз рӯи корбар ҷудост — ба корбари нав намерасад.
  static void clearAllCaches() {
    _memCache = null;
    _memCacheTime = null;
  }

  bool get _memCacheValid =>
      _memCache != null &&
      _memCacheTime != null &&
      DateTime.now().difference(_memCacheTime!) < _memCacheTTL;

  Future<void> _saveToDisk(List<ReelModel> reels) => OfflineCache.put(
      _diskCacheName, reels.map((r) => r.toJson()).toList(),
      maxItems: _diskCacheMax);

  Future<List<ReelModel>?> _loadFromDisk() async {
    try {
      final c = await OfflineCache.get(_diskCacheName);
      if (c == null || c.data is! List) return null;
      return (c.data as List)
          .map((e) => ReelModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) { return null; }
  }

  // ✅ МУШКИЛИ АСОСӢ ИСЛОҲ ШУД:
  // Page 1 → аввал кэш, баъд network background-да
  Future<List<ReelModel>> fetchReels({
    int page = 1, int limit = 20, bool smart = true,
    bool friends = false, bool forceRefresh = false}) async {

    lastFromCache = false;
    // ── Page 1: cache аввал (кэш танҳо барои лентаи умумӣ) ───────
    // Навсозии фонӣ дар экран аст (бо натиҷа ба экран, на танҳо ба диск).
    if (page == 1 && !friends && !forceRefresh) {
      if (_memCacheValid) return _memCache!;

      final disk = await _loadFromDisk();
      if (disk != null && disk.isNotEmpty) {
        _memCache     = disk;
        _memCacheTime = DateTime.now();
        lastFromCache = true;
        return disk; // ← ФАВРАН!
      }
    }

    // ── Network ──────────────────────────────────────────────────
    try {
      if (smart && !friends) {
        try {
          final res = await _api.get('/reels/smart',
              query: {'page': '$page', 'limit': '$limit'});

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
            if (friends) 'friends': '1'});

      if (res.statusCode == 401) throw Exception('Unauthorized');
      if (res.statusCode >= 400) throw ApiException(res.statusCode, res.body);

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
        if (_memCache != null && _memCache!.isNotEmpty) {
          lastFromCache = true;
          return _memCache!;
        }
        final disk = await _loadFromDisk();
        if (disk != null && disk.isNotEmpty) {
          lastFromCache = true;
          return disk;
        }
      }
      rethrow;
    }
  }

  /// Танҳо барои ҷавоби ШАБАКА (на кэши диск): ҳолати обуна аз сервер
  /// бо вақти гирифтан ба FollowService меравад ва кэши куҳнаро иваз
  /// мекунад — ҳатто агар Reels аллакай аз диск нишон дода шуда бошад.
  List<ReelModel> _parse(dynamic body) {
    final List list = body is Map
        ? (body['reels'] ?? body['data'] ?? []) : body as List;
    final reels = list.map((e) =>
        ReelModel.fromJson(e as Map<String, dynamic>)).toList();
    for (final r in reels) {
      FollowService.instance.prime(r.user.id, r.user.isFollowing,
          fetchedAt: r.fetchedAt ?? DateTime.now());
    }
    return reels;
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
      final res = await _api.get('${ApiEndpoints.reels}/$reelId/comments');
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
