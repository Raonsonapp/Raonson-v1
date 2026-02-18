import 'dart:convert';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../models/reel_model.dart';

class ProfileRepository {
  final ApiClient _api;

  ProfileRepository(this._api);

  // ================= PROFILE =================

  Future<UserModel> getProfile(String userId) async {
    final res = await _api.get('/users/$userId');
    return UserModel.fromJson(jsonDecode(res.body));
  }

  Future<void> updateProfile({
    required String username,
    String? bio,
    bool? isPrivate,
  }) async {
    await _api.post(
      ApiEndpoints.updateProfile,
      body: {
        'username': username,
        'bio': bio,
        'isPrivate': isPrivate,
      },
    );
  }

  // ================= FOLLOW =================

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

  // ================= POSTS =================

  Future<List<PostModel>> getUserPosts(String userId) async {
    final res = await _api.get('/users/$userId/posts');
    final List list = jsonDecode(res.body);
    return list.map((e) => PostModel.fromJson(e)).toList();
  }

  // ================= REELS =================

  Future<List<ReelModel>> getUserReels(String userId) async {
    final res = await _api.get('/users/$userId/reels');
    final List list = jsonDecode(res.body);
    return list.map((e) => ReelModel.fromJson(e)).toList();
  }
}
