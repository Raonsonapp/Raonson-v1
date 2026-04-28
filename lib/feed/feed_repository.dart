import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import 'feed_exceptions.dart';

class FeedRepository {
  final ApiClient _api = ApiClient.instance;

  List<PostModel>? _memCache;
  DateTime?        _memCacheTime;
  static const _memCacheTTL  = Duration(minutes: 2);
  static const _diskCacheKey = 'feed_posts_cache';
  static const _diskCacheTTL = Duration(hours: 24);

  bool get _memCacheValid =>
      _memCache != null &&
      _memCacheTime != null &&
      DateTime.now().difference(_memCacheTime!) < _memCacheTTL;

  Future<void> _saveToDisk(List<PostModel> posts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = {
        'time': DateTime.now().millisecondsSinceEpoch,
        'posts': posts.map((p) => p.toJson()).toList(),
      };
      await prefs.setString(_diskCacheKey, jsonEncode(payload));
    } catch (_) {}
  }

  Future<List<PostModel>?> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_diskCacheKey);
      if (raw == null) return null;
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final time = payload['time'] as int;
      final age  = DateTime.now().millisecondsSinceEpoch - time;
      if (age > _diskCacheTTL.inMilliseconds) return null;
      final list = payload['posts'] as List;
      return list
          .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) { return null; }
  }

  Future<List<PostModel>> fetchFeed({
    int limit = 10,
    int page = 1,
    bool forceRefresh = false,
    bool smartFeed = true, // ← Smart Feed интеграция
  }) async {
    if (page == 1 && !forceRefresh && _memCacheValid) return _memCache!;

    try {
      // Smart feed endpoint-ро аввал озмой, баъд одди
      final endpoint = smartFeed
          ? '/posts/smart-feed'
          : ApiEndpoints.posts;

      final query = <String, String>{
        'limit': '$limit',
        'page':  '$page',
        if (forceRefresh) 't': '${DateTime.now().millisecondsSinceEpoch}',
      };

      final response = await _api.getRequest(endpoint, query: query)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) throw const UnauthorizedException();

      // Smart feed 404/405 → одди endpoint-га ироз
      if (response.statusCode == 404 || response.statusCode == 405) {
        return _fetchRegularFeed(limit: limit, page: page,
            forceRefresh: forceRefresh);
      }

      if (response.statusCode >= 400) {
        throw Exception('Server error ${response.statusCode}');
      }

      final body = jsonDecode(response.body);
      List list = [];
      if (body is List)     { list = body; }
      else if (body is Map) { list = (body['posts'] ?? body['data'] ?? []); }

      final posts = list
          .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
          .toList();

      if (page == 1) {
        _memCache     = posts;
        _memCacheTime = DateTime.now();
        _saveToDisk(posts);
      }
      return posts;
    } on UnauthorizedException {
      rethrow;
    } catch (_) {
      if (page == 1) {
        final diskPosts = await _loadFromDisk();
        if (diskPosts != null && diskPosts.isNotEmpty) return diskPosts;
        if (_memCache != null) return _memCache!;
      }
      rethrow;
    }
  }

  // Одди endpoint — запас
  Future<List<PostModel>> _fetchRegularFeed({
    int limit = 10, int page = 1, bool forceRefresh = false}) async {
    final query = <String, String>{
      'limit': '$limit', 'page': '$page',
      if (forceRefresh) 't': '${DateTime.now().millisecondsSinceEpoch}',
    };
    final response = await _api.getRequest(ApiEndpoints.posts, query: query)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode >= 400) {
      throw Exception('Server error ${response.statusCode}');
    }

    final body = jsonDecode(response.body);
    List list = [];
    if (body is List)     { list = body; }
    else if (body is Map) { list = (body['posts'] ?? body['data'] ?? []); }

    final posts = list
        .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
        .toList();

    if (page == 1) {
      _memCache     = posts;
      _memCacheTime = DateTime.now();
      _saveToDisk(posts);
    }
    return posts;
  }

  void clearCache() {
    _memCache     = null;
    _memCacheTime = null;
  }

  Future<void> likePost(String postId) async =>
      _api.postRequest('/posts/$postId/like');

  Future<void> savePost(String postId) async =>
      _api.postRequest('/posts/$postId/save');

  Future<void> deletePost(String postId) async =>
      _api.deleteRequest('/posts/$postId');

  Future<List<CommentModel>> fetchComments(String postId) async {
    final response = await _api.getRequest('/comments/$postId');
    if (response.statusCode >= 400) throw Exception('Failed to load comments');
    final body = jsonDecode(response.body);
    final List list = body is Map ? (body['comments'] ?? []) : body as List;
    return list
        .map((e) => CommentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CommentModel> addComment({
    required String postId,
    required String text,
  }) async {
    final response = await _api.postRequest(
      '/comments/$postId', body: {'text': text});
    if (response.statusCode >= 400) throw Exception('Failed to add comment');
    return CommentModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> likeComment({
    required String postId,
    required String commentId,
  }) async => _api.postRequest('/comments/$commentId/like');
}
