// lib/profile/profile_repository.dart
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../models/reel_model.dart';
import 'highlight_model.dart';

class ProfileRepository {
  final ApiClient _api;
  ProfileRepository(this._api);

  static const _diskCacheTTL = Duration(hours: 24);

  String _profileKey(String id) => 'profile_cache_$id';
  String _postsKey(String id)   => 'profile_posts_$id';
  String _reelsKey(String id)   => 'profile_reels_$id';

  Future<void> _save(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode({
        'time': DateTime.now().millisecondsSinceEpoch,
        'data': data,
      }));
    } catch (_) {}
  }

  Future<dynamic> _load(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final age = DateTime.now().millisecondsSinceEpoch - (payload['time'] as int);
      if (age > _diskCacheTTL.inMilliseconds) return null;
      return payload['data'];
    } catch (_) { return null; }
  }

  // ✅ Cache аввал → baъд network
  Future<UserModel> getProfile(String userId) async {
    final path = userId == 'me' ? '/profile/me'
        : _isUUID(userId) ? '/users/$userId' : '/profile/$userId';
    final cacheKey = _profileKey(userId);

    final cached = await _load(cacheKey);
    if (cached != null) {
      _refreshProfile(path, cacheKey);
      return UserModel.fromJson(cached as Map<String, dynamic>);
    }
    return _fetchProfile(path, cacheKey);
  }

  Future<UserModel> _fetchProfile(String path, String cacheKey) async {
    final res = await _api.get(path).timeout(const Duration(seconds: 8));
    if (res.statusCode >= 400) throw Exception('Корбар ёфт нашуд');
    final body = jsonDecode(res.body);
    final j = (body is Map && body.containsKey('user')) ? body['user'] : body;
    await _save(cacheKey, j);
    return UserModel.fromJson(j as Map<String, dynamic>);
  }

  void _refreshProfile(String path, String cacheKey) {
    Future.delayed(const Duration(milliseconds: 800), () async {
      try { await _fetchProfile(path, cacheKey); } catch (_) {}
    });
  }

  Future<bool> isUsernameTaken(String username, String currentUsername) async {
    if (username.toLowerCase() == currentUsername.toLowerCase()) return false;
    try {
      return (await _api.get('/profile/$username')).statusCode == 200;
    } catch (_) { return false; }
  }

  Future<void> updateProfile({
    required String username, String? bio, String? fullName,
    String? website, bool? isPrivate, String? avatar,
    Map<String, dynamic>? bioSong,
  }) async {
    final res = await _api.put('/profile/', body: {
      'username': username,
      if (bio       != null) 'bio':       bio,
      if (fullName  != null) 'fullName':  fullName,
      if (website   != null) 'website':   website,
      if (isPrivate != null) 'isPrivate': isPrivate,
      if (avatar    != null && avatar.isNotEmpty) 'avatar': avatar,
      if (bioSong   != null) 'bioSong':   bioSong,
    });
    if (res.statusCode == 409) throw Exception('409: Username already taken');
    if (res.statusCode >= 400) {
      final b = jsonDecode(res.body) as Map<String,dynamic>? ?? {};
      throw Exception(b['message'] ?? 'Update failed ${res.statusCode}');
    }
  }

  Future<List<PostModel>> getUserPosts(String userId) async {
    final cacheKey = _postsKey(userId);
    final cached = await _load(cacheKey);
    if (cached != null) {
      _refreshPosts(userId, cacheKey);
      return (cached as List)
          .map((e) => PostModel.fromJson(e as Map<String,dynamic>)).toList();
    }
    return _fetchPosts(userId, cacheKey);
  }

  Future<List<PostModel>> _fetchPosts(String userId, String cacheKey) async {
    try {
      if (userId == 'me') {
        final res = await _api.get('/profile/me').timeout(const Duration(seconds: 8));
        if (res.statusCode >= 400) return [];
        final body = jsonDecode(res.body);
        if (body is Map && body.containsKey('posts')) {
          final list = body['posts'] as List;
          await _save(cacheKey, list);
          return list.map((e) => PostModel.fromJson(e as Map<String,dynamic>)).toList();
        }
        return [];
      }
      final res = await _api.get('/users/$userId/posts').timeout(const Duration(seconds: 8));
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      final raw  = body is List ? body : (body['posts'] ?? []) as List;
      await _save(cacheKey, raw);
      return raw.map((e) => PostModel.fromJson(e as Map<String,dynamic>)).toList();
    } catch (_) { return []; }
  }

  void _refreshPosts(String userId, String cacheKey) {
    Future.delayed(const Duration(milliseconds: 800), () async {
      try { await _fetchPosts(userId, cacheKey); } catch (_) {}
    });
  }

  Future<List<PostModel>> getTaggedPosts(String userId) async {
    try {
      final res = await _api.get('/users/$userId/tagged').timeout(const Duration(seconds: 8));
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      final list = body is List ? body : (body['posts'] ?? []) as List;
      return list.map((e) => PostModel.fromJson(e as Map<String,dynamic>)).toList();
    } catch (_) { return []; }
  }

  Future<List<ReelModel>> getUserReels(String userId) async {
    final cacheKey = _reelsKey(userId);
    final cached = await _load(cacheKey);
    if (cached != null) {
      _refreshReels(userId, cacheKey);
      return (cached as List)
          .map((e) => ReelModel.fromJson(e as Map<String,dynamic>)).toList();
    }
    return _fetchReels(userId, cacheKey);
  }

  Future<List<ReelModel>> _fetchReels(String userId, String cacheKey) async {
    try {
      final res = await _api.get('/users/$userId/reels').timeout(const Duration(seconds: 8));
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      final raw  = body is List ? body : (body['reels'] ?? []) as List;
      await _save(cacheKey, raw);
      return raw.map((e) => ReelModel.fromJson(e as Map<String,dynamic>)).toList();
    } catch (_) { return []; }
  }

  void _refreshReels(String userId, String cacheKey) {
    Future.delayed(const Duration(milliseconds: 800), () async {
      try { await _fetchReels(userId, cacheKey); } catch (_) {}
    });
  }

  Future<List<HighlightModel>> getHighlights(String userId) async {
    try {
      final res = await _api.get('/highlights/$userId').timeout(const Duration(seconds: 8));
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      final list = body is List ? body : (body['highlights'] ?? []) as List;
      return list.map((e) => HighlightModel.fromJson(e as Map<String,dynamic>)).toList();
    } catch (_) { return []; }
  }

  Future<void> follow(String uid)    async => _api.post(ApiEndpoints.follow(uid));
  Future<void> unfollow(String uid)  async => _api.post(ApiEndpoints.unfollow(uid));
  Future<void> blockUser(String uid)   async => _api.post('/users/$uid/block');
  Future<void> unblockUser(String uid) async => _api.post('/users/$uid/unblock');
  Future<void> pinPost(String postId, bool pin) async =>
      _api.post('/posts/$postId/pin', body: {'pin': pin});
  Future<void> deletePost(String postId) async => _api.delete('/posts/$postId');

  Future<List<UserModel>> getFollowers(String uid) async {
    final res = await _api.get('/users/$uid/followers');
    if (res.statusCode >= 400) return [];
    final body = jsonDecode(res.body);
    final list = body is List ? body : (body['followers'] ?? []) as List;
    return list.map((e) => UserModel.fromJson(e as Map<String,dynamic>)).toList();
  }

  Future<List<UserModel>> getFollowing(String uid) async {
    final res = await _api.get('/users/$uid/following');
    if (res.statusCode >= 400) return [];
    final body = jsonDecode(res.body);
    final list = body is List ? body : (body['following'] ?? []) as List;
    return list.map((e) => UserModel.fromJson(e as Map<String,dynamic>)).toList();
  }

  bool _isUUID(String s) =>
      RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
             r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(s);

  /// Resolve @username → userId via API
  Future<String> getUserIdByUsername(String username) async {
    try {
      final resp = await _api.get('/users/by-username/$username');
      if (resp.statusCode >= 400) return username;
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return (body['id'] ?? body['_id'] ?? username) as String;
    } catch (_) {
      return username;
    }
  }
}

// ── Extension methods — called by ProfileController ──────────────────────
extension ProfileRepositoryExt on ProfileRepository {

  /// Saved posts — GET /profile/saved
  Future<List<PostModel>> getSavedPosts() async {
    try {
      final res = await _api.get('/profile/saved')
          .timeout(const Duration(seconds: 8));
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      final list = body is List
          ? body
          : (body['posts'] ?? body['saved'] ?? []) as List;
      return list
          .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Upload avatar — stub kept for API compatibility
  /// Actual upload is done via UploadManager in ProfileController
  Future<String> uploadAvatar(File file) async => '';

  /// Remove avatar — DELETE /profile/avatar
  Future<void> removeAvatar() async {
    try {
      await _api.delete('/profile/avatar');
    } catch (_) {}
  }

  /// Create highlight
  Future<HighlightModel> createHighlight({
    required String title,
    required String coverUrl,
    required List<String> storyIds,
    List<HighlightItem> items = const [],
  }) async {
    final res = await _api.post('/highlights/', body: {
      'title': title, 'coverUrl': coverUrl, 'storyIds': storyIds,
      'items': items.map((e) => e.toJson()).toList(),
    });
    if (res.statusCode >= 400) throw Exception('Create highlight failed');
    return HighlightModel.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Rename / update highlight (title, cover, items)
  Future<void> updateHighlight(String id,
      {String? title, String? coverUrl, List<HighlightItem>? items}) async {
    try {
      await _api.patch('/highlights/$id', body: {
        if (title != null) 'title': title,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (items != null) 'items': items.map((e) => e.toJson()).toList(),
      });
    } catch (_) {}
  }

  /// Delete highlight
  Future<void> deleteHighlight(String id) async {
    try {
      await _api.delete('/highlights/$id');
    } catch (_) {}
  }
}
