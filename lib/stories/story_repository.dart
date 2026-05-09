// lib/stories/story_repository.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/story_model.dart';

class StoryRepository {
  final ApiClient _api;
  StoryRepository(this._api);

  static const _cacheKey = 'stories_cache_v1';
  static const _cacheTTL = Duration(minutes: 30);

  // ✅ Cache аввал → network background
  Future<List<StoryModel>> fetchStories() async {
    // Cache
    final cached = await _loadCache();
    if (cached != null) {
      _refreshBackground();
      return cached;
    }
    return _fetchFromNetwork();
  }

  Future<List<StoryModel>?> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final age = DateTime.now().millisecondsSinceEpoch - (payload['time'] as int);
      if (age > _cacheTTL.inMilliseconds) return null;
      final list = payload['data'] as List;
      return list.map((e) =>
          StoryModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) { return null; }
  }

  Future<List<StoryModel>> _fetchFromNetwork() async {
    try {
      final res = await _api.get(ApiEndpoints.stories)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      final raw = _extractList(body);
      // Cache-га сақла
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode({
        'time': DateTime.now().millisecondsSinceEpoch,
        'data': raw,
      }));
      return raw.map((e) =>
          StoryModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) { return []; }
  }

  void _refreshBackground() {
    Future.delayed(const Duration(seconds: 1), () async {
      try { await _fetchFromNetwork(); } catch (_) {}
    });
  }

  Future<List<StoryModel>> fetchMyStories() async {
    try {
      final res = await _api.get('${ApiEndpoints.stories}/my')
          .timeout(const Duration(seconds: 8));
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      return _extractList(body)
          .map((e) => StoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) { return []; }
  }

  Future<void> markStoryViewed(String storyId) async {
    try { await _api.post('${ApiEndpoints.stories}/$storyId/view'); }
    catch (_) {}
  }

  Future<void> likeStory(String storyId) async {
    try { await _api.post('${ApiEndpoints.stories}/$storyId/like'); }
    catch (_) {}
  }

  Future<void> replyToStory(String storyId, String text) async {
    try {
      await _api.post('${ApiEndpoints.stories}/$storyId/reply',
          body: {'text': text});
    } catch (_) {}
  }

  Future<Map<String, dynamic>> getViewers(String storyId) async {
    try {
      final res = await _api.get('${ApiEndpoints.stories}/$storyId/viewers')
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  List _extractList(dynamic body) {
    if (body is List) return body;
    if (body is Map) {
      return body['stories'] ?? body['data'] ?? body['items'] ?? [];
    }
    return [];
  }
}
