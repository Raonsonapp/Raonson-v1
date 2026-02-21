import 'dart:convert';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../models/reel_model.dart';

class ProfileRepository {
  final ApiClient _api;
  ProfileRepository(this._api);

  Future<UserModel> getProfile(String userId) async {
    final endpoint = userId == 'me' ? '/profile/me' : '/profile/$userId';
    final res = await _api.get(endpoint);
    if (res.statusCode >= 400) throw Exception('Profile not found');
    final body = jsonDecode(res.body);
    final userJson = body is Map && body.containsKey('user')
        ? body['user']
        : body;
    return UserModel.fromJson(userJson as Map<String, dynamic>);
  }

  Future<void> updateProfile({
    required String username,
    String? bio,
    bool? isPrivate,
  }) async {
    await _api.put(ApiEndpoints.updateProfile, body: {
      'username': username,
      if (bio != null) 'bio': bio,
      if (isPrivate != null) 'isPrivate': isPrivate,
    });
  }

  Future<List<PostModel>> getUserPosts(String userId) async {
    // For own profile use /profile/me which returns {user, posts}
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
    final media = rawMedia.map((m) {
      final map = m as Map;
      return <String, String>{
        'url': (map['url'] ?? '').toString(),
        'type': (map['type'] ?? 'image').toString(),
      };
    }).toList();
    return PostModel(
      id: (json['_id'] ?? '').toString(),
      user: json['user'] != null
          ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
          : const UserModel(
              id: '', username: '', avatar: '', verified: false,
              isPrivate: false, postsCount: 0, followersCount: 0, followingCount: 0),
      caption: (json['caption'] ?? '').toString(),
      media: media,
      likesCount: json['likesCount'] ??
          (json['likes'] is List ? (json['likes'] as List).length : 0),
      commentsCount: json['commentsCount'] ?? 0,
      liked: json['liked'] ?? false,
      saved: json['saved'] ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Future<List<ReelModel>> getUserReels(String userId) async {
    final id = userId == 'me' ? 'me' : userId;
    try {
      final res = await _api.get('/users/$id/reels');
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      final List list = body is List ? body : (body['reels'] ?? []);
      return list.map((e) => ReelModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<UserModel>> getFollowers(String userId) async {
    final res = await _api.get('/users/$userId/followers');
    if (res.statusCode >= 400) return [];
    final List list = jsonDecode(res.body);
    return list.map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<UserModel>> getFollowing(String userId) async {
    final res = await _api.get('/users/$userId/following');
    if (res.statusCode >= 400) return [];
    final List list = jsonDecode(res.body);
    return list.map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> follow(String userId) async {
    await _api.post(ApiEndpoints.follow(userId));
  }

  Future<void> unfollow(String userId) async {
    await _api.post(ApiEndpoints.unfollow(userId));
  }
}
