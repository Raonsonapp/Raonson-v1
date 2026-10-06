import 'dart:convert';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/storage/offline_cache.dart';
import 'feed_exceptions.dart';

class FeedRepository {
  final ApiClient _api = ApiClient.instance;

  // ── Memory cache ─────────────────────────────────────────────────
  static List<PostModel>? _memCache;
  static DateTime?        _memCacheTime;
  static const _memCacheTTL  = Duration(minutes: 5);
  /// Кэши диск дар [OfflineCache] — ба корбар баста ва бе мӯҳлати
  /// «куҳна шудан» (то 30 рӯз): бе интернет лентаи охирин нишон дода
  /// мешавад, на экрани холӣ.
  static const _diskCacheName = 'feed';
  static const _diskCacheMax  = 30;

  /// Натиҷаи охирини [fetchFeed] аз кэш буд (на аз шабака) — контроллер
  /// баннери «Офлайн» нишон медиҳад ва дар фон нав мекунад.
  bool lastFromCache = false;

  bool get _memCacheValid =>
      _memCache != null &&
      _memCacheTime != null &&
      DateTime.now().difference(_memCacheTime!) < _memCacheTTL;

  Future<void> _saveToDisk(List<PostModel> posts) => OfflineCache.put(
      _diskCacheName, posts.map((p) => p.toJson()).toList(),
      maxItems: _diskCacheMax);

  Future<List<PostModel>?> _loadFromDisk() async {
    try {
      final c = await OfflineCache.get(_diskCacheName);
      if (c == null || c.data is! List) return null;
      return (c.data as List)
          .map((e) => PostModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) { return null; }
  }

  /// Кэши лентаро танҳо саҳифаи пурра иваз мекунад — санҷиши пинҳонии
  /// постҳои нав (limit: 5) кэши 10+ постро бо 5 иваз намекунад.
  void _remember(List<PostModel> posts, int limit) {
    _memCache     = posts;
    _memCacheTime = DateTime.now();
    if (limit >= 10) _saveToDisk(posts);
  }

  // ✅ МУШКИЛИ АСОСӢ ИСЛОҲ ШУД:
  // Аввал cache нишон деҳ → баъд network
  // Ҳеҷ гоҳ blank нест!
  Future<List<PostModel>> fetchFeed({
    int limit = 10,
    int page = 1,
    bool forceRefresh = false,
    bool smartFeed = true,
    String mode = '',
  }) async {
    // «Обунаҳо» / «Дӯстдоштаҳо» — лентаҳои алоҳида бо тартиби вақт,
    // мисли Instagram. Кэши лентаи асосӣ ба онҳо даст намерасонад,
    // вагарна ҳангоми гузаштан постҳои режими дигар мебаромаданд.
    if (mode.isNotEmpty) {
      // Офлайн: ин лентаҳо кэши диск надоранд — экрани режим ҳангоми
      // хатои шабака худаш хабари фаҳмо нишон медиҳад. Кэши лентаи асосӣ
      // ҳеҷ гоҳ ба ҷои онҳо нишон дода намешавад (постҳои режими дигар).
      // Timeout ва такрори GET дар ApiClient аст (15 с + 1 такрор).
      final response = await _api.getRequest(ApiEndpoints.posts, query: {
        'limit': '$limit', 'page': '$page', 'mode': mode,
        if (forceRefresh) 't': '${DateTime.now().millisecondsSinceEpoch}',
      });
      if (response.statusCode == 401) throw const UnauthorizedException();
      if (response.statusCode >= 400) {
        throw Exception('Server ${response.statusCode}');
      }
      final body = jsonDecode(response.body);
      final List list = body is List
          ? body
          : (body is Map ? (body['posts'] ?? body['data'] ?? []) : []);
      return list
          .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    lastFromCache = false;
    // ── Page 1: аввал cache ──────────────────────────────────────
    if (page == 1 && !forceRefresh) {
      // 1. Memory cache (тезтарин)
      if (_memCacheValid) return _memCache!;

      // 2. Disk cache (фавран) — навсозиро контроллер дар фон мекунад.
      final diskCache = await _loadFromDisk();
      if (diskCache != null && diskCache.isNotEmpty) {
        _memCache     = diskCache;
        _memCacheTime = DateTime.now();
        lastFromCache = true;
        return diskCache; // ← ФАВРАН cache нишон деҳ!
      }
    }

    // ── Network fetch ─────────────────────────────────────────────
    try {
      final endpoint = smartFeed ? '/posts/smart-feed' : ApiEndpoints.posts;
      final query = <String, String>{
        'limit': '$limit',
        'page':  '$page',
        if (forceRefresh) 't': '${DateTime.now().millisecondsSinceEpoch}',
      };

      final response = await _api.getRequest(endpoint, query: query);

      if (response.statusCode == 401) throw const UnauthorizedException();

      // Smart feed 404 → одди endpoint
      if (response.statusCode == 404 || response.statusCode == 405) {
        return await _fetchRegularFeed(limit: limit, page: page,
            forceRefresh: forceRefresh);
      }

      if (response.statusCode >= 400) {
        throw ApiException(response.statusCode, response.body);
      }

      final body = jsonDecode(response.body);
      List list = [];
      if (body is List)     { list = body; }
      else if (body is Map) { list = (body['posts'] ?? body['data'] ?? []); }

      final posts = list
          .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
          .toList();

      if (page == 1) _remember(posts, limit);
      return posts;

    } on UnauthorizedException {
      rethrow;
    } catch (_) {
      // ✅ Хато → кэш нишон деҳ, ҳеҷ гоҳ blank не!
      if (page == 1) {
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

  Future<List<PostModel>> _fetchRegularFeed({
    int limit = 10, int page = 1, bool forceRefresh = false}) async {
    final query = <String, String>{
      'limit': '$limit', 'page': '$page',
      if (forceRefresh) 't': '${DateTime.now().millisecondsSinceEpoch}',
    };
    final response = await _api.getRequest(ApiEndpoints.posts, query: query);

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, response.body);
    }

    final body = jsonDecode(response.body);
    List list = [];
    if (body is List)     { list = body; }
    else if (body is Map) { list = (body['posts'] ?? body['data'] ?? []); }

    final posts = list
        .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
        .toList();

    if (page == 1) _remember(posts, limit);
    return posts;
  }

  void clearCache() {
    _memCache     = null;
    _memCacheTime = null;
  }

  // Barои иваз кардани аккаунт — cache-и static-ро (барои ҳамаи instance)
  // тоза мекунем, то FeedScreen корбари нав пости куҳнаро набинад.
  static void clearAllCaches() {
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
    if (response.statusCode >= 400) throw Exception('Failed comments');
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
    if (response.statusCode >= 400) throw Exception('Failed comment');
    return CommentModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> likeComment({
    required String postId,
    required String commentId,
  }) async => _api.postRequest('/comments/$commentId/like');
}
