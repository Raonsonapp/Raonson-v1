// lib/profile/profile_repository.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../app/app_config.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/storage/token_storage.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../models/reel_model.dart';
import 'highlight_model.dart';

class ProfileRepository {
  final ApiClient _api;
  ProfileRepository(this._api);

  static const _ttl = Duration(hours: 24);

  // ─── Cache helpers ─────────────────────────────────────────────
  Future<void> _save(String key, dynamic data) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(key, jsonEncode({
        'time': DateTime.now().millisecondsSinceEpoch,
        'data': data,
      }));
    } catch (_) {}
  }

  Future<dynamic> _load(String key) async {
    try {
      final p   = await SharedPreferences.getInstance();
      final raw = p.getString(key);
      if (raw == null) return null;
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final age = DateTime.now().millisecondsSinceEpoch - (payload['time'] as int);
      if (age > _ttl.inMilliseconds) return null;
      return payload['data'];
    } catch (_) { return null; }
  }

  // ─── Profile ───────────────────────────────────────────────────
  Future<UserModel> getProfile(String userId) async {
    final path = userId == 'me' ? '/profile/me'
        : _isUUID(userId) ? '/users/$userId' : '/profile/$userId';
    final key = 'profile_$userId';
    final cached = await _load(key);
    if (cached != null) {
      _bg(() => _fetchProfile(path, key));
      return UserModel.fromJson(cached as Map<String, dynamic>);
    }
    return _fetchProfile(path, key);
  }

  Future<UserModel> _fetchProfile(String path, String key) async {
    final res = await _api.get(path).timeout(const Duration(seconds: 8));
    if (res.statusCode >= 400) throw Exception('Корбар ёфт нашуд');
    final body = jsonDecode(res.body);
    final j = (body is Map && body.containsKey('user')) ? body['user'] : body;
    await _save(key, j);
    return UserModel.fromJson(j as Map<String, dynamic>);
  }

  Future<bool> isUsernameTaken(String username, String current) async {
    if (username.toLowerCase() == current.toLowerCase()) return false;
    try {
      return (await _api.get('/profile/$username')).statusCode == 200;
    } catch (_) { return false; }
  }

  Future<void> updateProfile({
    required String username,
    String? bio, String? fullName, String? website,
    bool? isPrivate, String? avatar,
    String? gender, String? location, String? birthday,
  }) async {
    final res = await _api.put('/profile/', body: {
      'username': username,
      if (bio       != null) 'bio':       bio,
      if (fullName  != null) 'fullName':  fullName,
      if (website   != null) 'website':   website,
      if (isPrivate != null) 'isPrivate': isPrivate,
      if (avatar    != null && avatar.isNotEmpty) 'avatar': avatar,
      if (gender    != null) 'gender':   gender,
      if (location  != null) 'location': location,
      if (birthday  != null) 'birthday': birthday,
    });
    if (res.statusCode == 409) throw Exception('409: Username already taken');
    if (res.statusCode >= 400) {
      final b = jsonDecode(res.body) as Map<String, dynamic>? ?? {};
      throw Exception(b['message'] ?? 'Update failed ${res.statusCode}');
    }
  }

  // Upload avatar multipart
  Future<String> uploadAvatar(File file) async {
    final token = await TokenStorage.getAccessToken();
    final uri   = Uri.parse('${AppConfig.apiBaseUrl}/profile/avatar');
    final req   = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('avatar', file.path));
    final streamed = await req.send().timeout(const Duration(seconds: 30));
    final res      = await http.Response.fromStream(streamed);
    if (res.statusCode >= 400) throw Exception('Upload failed');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['avatarUrl'] ?? body['url'] ?? body['avatar'] ?? '').toString();
  }

  Future<void> removeAvatar() async {
    await _api.delete('/profile/avatar');
  }

  // ─── Posts ─────────────────────────────────────────────────────
  Future<List<PostModel>> getUserPosts(String userId) async {
    final key    = 'posts_$userId';
    final cached = await _load(key);
    if (cached != null) {
      _bg(() => _fetchPosts(userId, key));
      return (cached as List)
          .map((e) => PostModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return _fetchPosts(userId, key);
  }

  Future<List<PostModel>> _fetchPosts(String userId, String key) async {
    try {
      if (userId == 'me') {
        final res = await _api.get('/profile/me').timeout(const Duration(seconds: 8));
        if (res.statusCode >= 400) return [];
        final body = jsonDecode(res.body);
        if (body is Map && body.containsKey('posts')) {
          final list = body['posts'] as List;
          await _save(key, list);
          return list.map((e) => PostModel.fromJson(e as Map<String, dynamic>)).toList();
        }
        return [];
      }
      final res = await _api.get('/users/$userId/posts')
          .timeout(const Duration(seconds: 8));
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      final raw  = body is List ? body : ((body['posts'] ?? []) as List);
      await _save(key, raw);
      return raw.map((e) => PostModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) { return []; }
  }

  Future<List<PostModel>> getTaggedPosts(String userId) async {
    try {
      final res = await _api.get('/users/$userId/tagged')
          .timeout(const Duration(seconds: 8));
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      final list = body is List ? body : ((body['posts'] ?? []) as List);
      return list.map((e) => PostModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) { return []; }
  }

  Future<List<PostModel>> getSavedPosts() async {
    try {
      final res = await _api.get('/profile/saved')
          .timeout(const Duration(seconds: 8));
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      final list = body is List ? body : ((body['posts'] ?? body['saved'] ?? []) as List);
      return list.map((e) => PostModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) { return []; }
  }

  Future<void> pinPost(String postId, bool pin) async =>
      _api.post('/posts/$postId/pin', body: {'pin': pin});
  Future<void> deletePost(String postId) async => _api.delete('/posts/$postId');

  // ─── Reels ─────────────────────────────────────────────────────
  Future<List<ReelModel>> getUserReels(String userId) async {
    final key    = 'reels_$userId';
    final cached = await _load(key);
    if (cached != null) {
      _bg(() => _fetchReels(userId, key));
      return (cached as List)
          .map((e) => ReelModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return _fetchReels(userId, key);
  }

  Future<List<ReelModel>> _fetchReels(String userId, String key) async {
    try {
      final res = await _api.get('/users/$userId/reels')
          .timeout(const Duration(seconds: 8));
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      final raw  = body is List ? body : ((body['reels'] ?? []) as List);
      await _save(key, raw);
      return raw.map((e) => ReelModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) { return []; }
  }

  // ─── Highlights ────────────────────────────────────────────────
  Future<List<HighlightModel>> getHighlights(String userId) async {
    try {
      final res = await _api.get('/highlights/$userId')
          .timeout(const Duration(seconds: 8));
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      final list = body is List ? body : ((body['highlights'] ?? []) as List);
      return list.map((e) => HighlightModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) { return []; }
  }

  Future<HighlightModel> createHighlight({
    required String title,
    required String coverUrl,
    required List<String> storyIds,
  }) async {
    final res = await _api.post('/highlights/', body: {
      'title': title, 'coverUrl': coverUrl, 'storyIds': storyIds,
    });
    if (res.statusCode >= 400) throw Exception('Create failed');
    return HighlightModel.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteHighlight(String id) async =>
      _api.delete('/highlights/$id');

  // ─── Follow / Block ────────────────────────────────────────────
  Future<void> follow(String uid)     async => _api.post(ApiEndpoints.follow(uid));
  Future<void> unfollow(String uid)   async => _api.post(ApiEndpoints.unfollow(uid));
  Future<void> blockUser(String uid)   async => _api.post('/users/$uid/block');
  Future<void> unblockUser(String uid) async => _api.post('/users/$uid/unblock');

  Future<List<UserModel>> getFollowers(String uid) async {
    final res = await _api.get('/users/$uid/followers');
    if (res.statusCode >= 400) return [];
    final body = jsonDecode(res.body);
    final list = body is List ? body : ((body['followers'] ?? []) as List);
    return list.map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<UserModel>> getFollowing(String uid) async {
    final res = await _api.get('/users/$uid/following');
    if (res.statusCode >= 400) return [];
    final body = jsonDecode(res.body);
    final list = body is List ? body : ((body['following'] ?? []) as List);
    return list.map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<String> getUserIdByUsername(String username) async {
    try {
      final res = await _api.get('/users/by-username/$username');
      if (res.statusCode >= 400) return username;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return (body['id'] ?? body['_id'] ?? username).toString();
    } catch (_) { return username; }
  }

  bool _isUUID(String s) =>
      RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
             r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(s);

  void _bg(Future<void> Function() fn) {
    Future.delayed(const Duration(milliseconds: 800), () async {
      try { await fn(); } catch (_) {}
    });
  }
}
