// lib/stories/story_repository.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/storage/offline_cache.dart';
import '../models/story_model.dart';

class StoryRepository {
  final ApiClient _api;
  StoryRepository(this._api);

  /// Кэш дар [OfflineCache] — ба корбар баста. То [_freshFor] ҳамчун
  /// «нав» фавран нишон дода мешавад (навсозӣ дар фон); то [_offlineFor]
  /// танҳо вақте ки шабака нашуд — сторисҳои мӯҳлаташон гузашта партофта
  /// мешаванд.
  static const _cacheName  = 'stories';
  static const _myName     = 'stories_my';
  static const _legacyKey  = 'stories_cache_v2';
  static const _freshFor   = Duration(minutes: 30);
  static const _offlineFor = Duration(hours: 24);

  // Пас аз иваз кардани аккаунт ё нашри сторис — кэшро тоза мекунем, то
  // ки рӯйхати нав аз шабака гирифта шавад.
  static Future<void> clearAllCaches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_legacyKey);
    } catch (_) {}
    await OfflineCache.remove(_cacheName);
    await OfflineCache.remove(_myName);
  }

  // ✅ Cache аввал → network background; шабака нашуд → кэши охирин.
  Future<List<StoryModel>> fetchStories() async {
    final fresh = await _loadCache(_cacheName, _freshFor);
    if (fresh != null) {
      _refreshBackground();
      return fresh;
    }
    return await _fetchFromNetwork() ??
        await _loadCache(_cacheName, _offlineFor) ?? [];
  }

  Future<List<StoryModel>?> _loadCache(String name, Duration maxAge) async {
    try {
      final c = await OfflineCache.get(name, maxAge: maxAge);
      if (c == null || c.data is! List) return null;
      final now = DateTime.now();
      return (c.data as List)
          .map((e) => StoryModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((s) => s.expiresAt.isAfter(now))
          .toList();
    } catch (_) { return null; }
  }

  /// `null` — шабака/сервер нашуд (кэш нигоҳ дошта мешавад).
  Future<List<StoryModel>?> _fetchFromNetwork() async {
    try {
      final res = await _api.get(ApiEndpoints.stories);
      if (res.statusCode >= 400) return null;
      final body = jsonDecode(res.body);
      final raw = _extractList(body);
      await OfflineCache.put(_cacheName, raw, maxItems: 120);
      return raw.map((e) =>
          StoryModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) { return null; }
  }

  void _refreshBackground() {
    Future.delayed(const Duration(seconds: 1), () async {
      try { await _fetchFromNetwork(); } catch (_) {}
    });
  }

  Future<List<StoryModel>> fetchMyStories() async {
    try {
      final res = await _api.get('${ApiEndpoints.stories}/my');
      if (res.statusCode >= 400) {
        return await _loadCache(_myName, _offlineFor) ?? [];
      }
      final body = jsonDecode(res.body);
      final raw = _extractList(body);
      await OfflineCache.put(_myName, raw, maxItems: 60);
      return raw
          .map((e) => StoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return await _loadCache(_myName, _offlineFor) ?? [];
    }
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
      final res = await _api.get('${ApiEndpoints.stories}/$storyId/viewers',
              query: const {'limit': '200'});
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
