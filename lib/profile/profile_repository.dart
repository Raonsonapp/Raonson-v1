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
  // userId = 'me'       → /profile/me
  // userId = objectId   → /users/:id   (search натиҷа ба ин мефиристад)
  // userId = username   → /profile/:username  (legacy)
  Future<UserModel> getProfile(String userId) async {
    if (userId == 'me') {
      final res = await _api.get('/profile/me');
      if (res.statusCode >= 400) throw Exception('Profile not found');
      final body = jsonDecode(res.body);
      final userJson = body is Map && body.containsKey('user')
          ? body['user'] : body;
      return UserModel.fromJson(userJson as Map<String, dynamic>);
    }

    // MongoDB ObjectId → /users/:id (findById)
    if (_isObjectId(userId)) {
      final res = await _api.get('/users/$userId');
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final userJson = body is Map && body.containsKey('user')
            ? body['user'] : body;
        return UserModel.fromJson(userJson as Map<String, dynamic>);
      }
    }

    // Username → /profile/:username
    final res = await _api.get('/profile/$userId');
    if (res.statusCode >= 400) throw Exception('User not found');
    final body = jsonDecode(res.body);
    final userJson = body is Map && body.containsKey('user')
        ? body['user'] : body;
    return UserModel.fromJson(userJson as Map<String, dynamic>);
  }

  // 24 hex char ObjectId?
  bool _isObjectId(String s) =>
      s.length == 24 && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(s);

  // ── Профилро таҳрир кун ───────────────────────────────────────
  Future<void> updateProfile({
    required String username,
    String? bio,
    bool?   isPrivate,
    String? avatar,
  }) async {
    await _api.put(ApiEndpoints.updateProfile, body: {
      'username': username,
      if (bio      != null) 'bio':       bio,
      if (isPrivate != null) 'isPrivate': isPrivate,
      if (avatar   != null && avatar.isNotEmpty) 'avatar': avatar,
    });
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
    // ObjectId or username → /users/:id/posts
    final id = _isObjectId(userId) ? userId : userId;
    final res = await _api.get('/users/$id/posts');
    if (res.statusCode >= 400) return [];
    final body = jsonDecode(res.body);
    final List list = body is List ? body : (body['posts'] ?? []);
    return list.map((e) => _parsePost(e as Map<String, dynamic>)).toList();
  }

  PostModel _parsePost(Map<String, dynamic> json) {
    final rawMedia = (json['media'] ?? []) as List;
    final media = rawMedia.map((m) {
      final map = m as Map;
      return <String, String>{
        'url':  (map['url']  ?? '').toString(),
        'type': (map['type'] ?? 'image').toString(),
      };
    }).toList();
    return PostModel(
      id:            (json['_id'] ?? '').toString(),
      user:          json['user'] != null
          ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
          : const UserModel(
              id: '', username: '', avatar: '', verified: false,
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
    final id = userId == 'me' ? 'me' : userId;
    try {
      final res = await _api.get('/users/$id/reels');
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      final List list = body is List ? body : (body['reels'] ?? []);
      return list
          .map((e) => ReelModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) { return []; }
  }

  // ── Follow / Unfollow ─────────────────────────────────────────
  Future<void> follow(String userId) async =>
      _api.post(ApiEndpoints.follow(userId));

  Future<void> unfollow(String userId) async =>
      _api.post(ApiEndpoints.unfollow(userId));

  // ── Followers / Following ─────────────────────────────────────
  Future<List<UserModel>> getFollowers(String userId) async {
    final res = await _api.get('/users/$userId/followers');
    if (res.statusCode >= 400) return [];
    final List list = jsonDecode(res.body);
    return list
        .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<UserModel>> getFollowing(String userId) async {
    final res = await _api.get('/users/$userId/following');
    if (res.statusCode >= 400) return [];
    final List list = jsonDecode(res.body);
    return list
        .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
