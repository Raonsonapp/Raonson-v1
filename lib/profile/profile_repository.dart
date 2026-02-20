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
    final res = await _api.get('/profile/${userId == 'me' ? 'me' : userId}');
    final body = jsonDecode(res.body);
    // Backend returns {user, posts} or just user object
    final userJson = body is Map && body.containsKey('user')
        ? body['user']
        : body;
    return UserModel.fromJson(userJson);
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

  Future<List<UserModel>> getFollowers(String userId) async {
    final res = await _api.get('/users/$userId/followers');
    final List list = jsonDecode(res.body);
    return list.map((e) => UserModel.fromJson(e)).toList();
  }

  Future<List<UserModel>> getFollowing(String userId) async {
    final res = await _api.get('/users/$userId/following');
    final List list = jsonDecode(res.body);
    return list.map((e) => UserModel.fromJson(e)).toList();
  }

  Future<void> follow(String userId) {
    return _api.post('/follow/$userId');
  }

  Future<void> unfollow(String userId) {
    return _api.post('/unfollow/$userId');
  }

  Future<List<PostModel>> getUserPosts(String userId) async {
    final res = await _api.get('/users/$userId/posts');
    final body = jsonDecode(res.body);
    final List list = body is List ? body : (body['posts'] ?? []);
    return list.map((e) => PostModel.fromJson(e)).toList();
  }

  Future<List<ReelModel>> getUserReels(String userId) async {
    final res = await _api.get('/users/$userId/reels');
    final body = jsonDecode(res.body);
    final List list = body is List ? body : (body['reels'] ?? []);
    return list.map((e) => ReelModel.fromJson(e)).toList();
  }
}
