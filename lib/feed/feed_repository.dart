import 'dart:convert';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import 'feed_exceptions.dart';

class FeedRepository {
  final ApiClient _api = ApiClient.instance;

  // ── Кэши хотира — page 1 ─────────────────────────────────────
  List<PostModel>? _cache;
  DateTime?        _cacheTime;
  static const _cacheTTL = Duration(minutes: 2);

  bool get _cacheValid =>
      _cache != null &&
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!) < _cacheTTL;

  Future<List<PostModel>> fetchFeed({
    int limit = 10,
    int page = 1,
    bool forceRefresh = false,
  }) async {
    // Кэш — page 1-ро зуд нишон деҳ
    if (page == 1 && !forceRefresh && _cacheValid) return _cache!;

    final query = <String, String>{
      'limit': '$limit',
      'page':  '$page',
      if (forceRefresh) 't': '${DateTime.now().millisecondsSinceEpoch}',
    };
    final response = await _api.getRequest(ApiEndpoints.posts, query: query);

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode >= 400) {
      throw Exception('Server error ${response.statusCode}');
    }

    final body = jsonDecode(response.body);
    List list = [];
    if (body is List)      { list = body; }
    else if (body is Map)  { list = (body['posts'] ?? body['data'] ?? []); }

    final posts = list
        .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
        .toList();

    // Кэш-ро навсоз
    if (page == 1) {
      _cache     = posts;
      _cacheTime = DateTime.now();
    }
    return posts;
  }

  void clearCache() {
    _cache     = null;
    _cacheTime = null;
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
      '/comments/$postId',
      body: {'text': text},
    );
    if (response.statusCode >= 400) throw Exception('Failed to add comment');
    return CommentModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> likeComment({
    required String postId,
    required String commentId,
  }) async =>
      _api.postRequest('/comments/$commentId/like');
}
