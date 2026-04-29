import 'dart:convert';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/reel_model.dart';

class ReelsRepository {
  final ApiClient _api;
  ReelsRepository(this._api);

  // ── Smart Feed бо fallback ────────────────────────────────────
  Future<List<ReelModel>> fetchReels({
    int page = 1, int limit = 20, bool smart = true}) async {

    if (smart) {
      try {
        final res = await _api.get('/reels/smart',
            query: {'page': '$page', 'limit': '$limit'})
            .timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          return _parse(jsonDecode(res.body));
        }
        // 404/405 → fallback
        if (res.statusCode != 404 && res.statusCode != 405) {
          if (res.statusCode == 401) throw Exception('Unauthorized');
          if (res.statusCode >= 400) throw Exception('Server ${res.statusCode}');
        }
      } catch (e) {
        if (e.toString().contains('Unauthorized')) rethrow;
        // Smart feed мавҷуд нест → одди
      }
    }

    // Одди endpoint
    final res = await _api.get(ApiEndpoints.reels,
        query: {'page': '$page', 'limit': '$limit'})
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 401) throw Exception('Unauthorized');
    if (res.statusCode >= 400) throw Exception('Server error ${res.statusCode}');

    return _parse(jsonDecode(res.body));
  }

  List<ReelModel> _parse(dynamic body) {
    final List list = body is Map
        ? (body['reels'] ?? body['data'] ?? []) : body as List;
    return list.map((e) =>
        ReelModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Like ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> likeReel(String reelId) async {
    try {
      final res = await _api.post('${ApiEndpoints.reels}/$reelId/like');
      if (res.statusCode < 400) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // ── Save ──────────────────────────────────────────────────────
  Future<void> saveReel(String reelId) async {
    try { await _api.post('${ApiEndpoints.reels}/$reelId/save'); } catch (_) {}
  }

  // ── Watch Time — алгоритмга сигнал ───────────────────────────
  Future<void> trackWatchTime({
    required String reelId,
    required int    watchMs,     // неча мс тамошо шуд
    required int    durationMs,  // умумии вақт
  }) async {
    try {
      await _api.post('${ApiEndpoints.reels}/$reelId/view', body: {
        'watchMs':    watchMs,
        'durationMs': durationMs,
      }).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  // ── Not Interested ────────────────────────────────────────────
  Future<void> markNotInterested(String reelId) async {
    try {
      await _api.post('${ApiEndpoints.reels}/$reelId/not_interest')
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  // ── Real Stats ────────────────────────────────────────────────
  Future<Map<String, dynamic>?> fetchStats(String reelId) async {
    try {
      final res = await _api.get('${ApiEndpoints.reels}/$reelId/stats')
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // ── Comments ──────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchComments(String reelId) async {
    try {
      final res = await _api.get('${ApiEndpoints.reels}/$reelId/comments');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data is List ? data : (data['comments'] ?? []);
        return List<Map<String, dynamic>>.from(list);
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> addComment({
    required String reelId, required String text}) async {
    try {
      final res = await _api.post('${ApiEndpoints.reels}/$reelId/comments',
          body: {'text': text});
      if (res.statusCode < 400) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> likeComment({
    required String reelId, required String commentId}) async {
    try {
      final res = await _api.post(
          '${ApiEndpoints.reels}/$reelId/comments/$commentId/like');
      if (res.statusCode < 400) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> replyComment({
    required String reelId,
    required String commentId,
    required String text,
  }) async {
    try {
      final res = await _api.post(
          '${ApiEndpoints.reels}/$reelId/comments/$commentId/reply',
          body: {'text': text});
      if (res.statusCode < 400) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}
