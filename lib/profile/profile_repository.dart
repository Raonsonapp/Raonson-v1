import 'dart:convert';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../models/reel_model.dart';

class ProfileRepository {
  final ApiClient _api;
  ProfileRepository(this._api);

  // ── Профили корбар ─────────────────────────────────────────────
  Future<UserModel> getProfile(String userId) async {
    if (userId == 'me') {
      final res = await _api.get('/profile/me');
      if (res.statusCode >= 400) throw Exception('Profile not found');
      final body     = jsonDecode(res.body);
      final userJson = (body is Map && body.containsKey('user'))
          ? body['user'] : body;
      return UserModel.fromJson(userJson as Map<String, dynamic>);
    }

    // UUID → /users/:id
    if (_isUUID(userId)) {
      final res = await _api.get('/users/$userId');
      if (res.statusCode == 200) {
        final body     = jsonDecode(res.body);
        final userJson = (body is Map && body.containsKey('user'))
            ? body['user'] : body;
        return UserModel.fromJson(userJson as Map<String, dynamic>);
      }
    }

    // Username → /profile/:username
    final res = await _api.get('/profile/$userId');
    if (res.statusCode >= 400) throw Exception('User not found');
    final body     = jsonDecode(res.body);
    final userJson = (body is Map && body.containsKey('user'))
        ? body['user'] : body;
    return UserModel.fromJson(userJson as Map<String, dynamic>);
  }

  // ── Username банд аст? ─────────────────────────────────────────
  // Backend /users/check-username нест → /profile/:username истифода мебарем
  Future<bool> isUsernameTaken(String username, String currentUsername) async {
    if (username.toLowerCase() == currentUsername.toLowerCase()) return false;
    try {
      final res = await _api.get('/profile/$username');
      // 200 → нафаре бо ин username ҳаст → банд
      // 404 → озод
      return res.statusCode == 200;
    } catch (_) {
      return false; // агар хато → фарз мекунем озод аст
    }
  }

  // ── Профилро таҳрир кун ───────────────────────────────────────
  // МУҲИМ: PUT /profile/ — бо trailing slash (backend: p.PUT("/"))
  Future<void> updateProfile({
    required String username,
    String? bio,
    bool?   isPrivate,
    String? avatar,
  }) async {
    final res = await _api.put(
      '/profile/', // ← trailing slash ЛОЗИМ
      body: {
        'username':  username,
        if (bio       != null) 'bio':       bio,
        if (isPrivate != null) 'isPrivate': isPrivate,
        if (avatar    != null && avatar.isNotEmpty) 'avatar': avatar,
      },
    );

    if (res.statusCode == 409) {
      throw Exception('409: Username already taken');
    }
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body) as Map<String, dynamic>? ?? {};
      throw Exception(body['message'] ?? 'Update failed ${res.statusCode}');
    }
  }

  // ── Постҳои корбар ────────────────────────────────────────────
  Future<List<PostModel>> getUserPosts(String userId) async {
    if (userId == 'me') {
      final res = await _api.get('/profile/me');
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      if (body is Map && body.containsKey('posts')) {
        final List list = body['posts'] as List;
        return list.map((e) => _parsePost(e as Map<String, dynamic>)).toList();
      }
      return [];
    }
    final res = await _api.get('/users/$userId/posts');
    if (res.statusCode >= 400) return [];
    final body = jsonDecode(res.body);
    final List list = body is List ? body : (body['posts'] ?? []);
    return list.map((e) => _parsePost(e as Map<String, dynamic>)).toList();
  }

  PostModel _parsePost(Map<String, dynamic> json) {
    final rawMedia = (json['media'] ?? []) as List;
    final media    = rawMedia.map((m) {
      final map = m as Map;
      return <String, String>{
        'url':  (map['url']  ?? '').toString(),
        'type': (map['type'] ?? 'image').toString(),
      };
    }).toList();

    return PostModel(
      id:            (json['_id'] ?? json['id'] ?? '').toString(),
      user:          json['user'] != null
          ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
          : const UserModel(id: '', username: '', avatar: '', verified: false,
              isPrivate: false, postsCount: 0,
              followersCount: 0, followingCount: 0),
      caption:       (json['caption'] ?? '').toString(),
      media:         media,
      likesCount:    json['likesCount'] ??
          (json['likes'] is List ? (json['likes'] as List).length : 0),
      commentsCount: json['commentsCount'] ?? 0,
      liked:         json['liked'] ?? false,
      saved:         json['saved'] ?? false,
      createdAt:     DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  // ── Рилҳои корбар ─────────────────────────────────────────────
  Future<List<ReelModel>> getUserReels(String userId) async {
    try {
      final res  = await _api.get('/users/$userId/reels');
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      final List list = body is List ? body : (body['reels'] ?? []);
      return list.map((e) => ReelModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) { return []; }
  }

  // ── Follow / Unfollow ─────────────────────────────────────────
  Future<void> follow(String userId)   async => _api.post(ApiEndpoints.follow(userId));
  Future<void> unfollow(String userId) async => _api.post(ApiEndpoints.unfollow(userId));

  // ── Followers / Following ─────────────────────────────────────
  Future<List<UserModel>> getFollowers(String userId) async {
    final res  = await _api.get('/users/$userId/followers');
    if (res.statusCode >= 400) return [];
    final body = jsonDecode(res.body);
    final List list = body is List ? body : (body['followers'] ?? []);
    return list.map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<UserModel>> getFollowing(String userId) async {
    final res  = await _api.get('/users/$userId/following');
    if (res.statusCode >= 400) return [];
    final body = jsonDecode(res.body);
    final List list = body is List ? body : (body['following'] ?? []);
    return list.map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Helpers ───────────────────────────────────────────────────
  bool _isUUID(String s) =>
      s.length == 36 &&
      RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
             r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(s);
}
