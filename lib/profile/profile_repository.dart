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
    final res = await _api.get(ApiEndpoints.userProfile(userId));
    return UserModel.fromJson(jsonDecode(res.data));
  }

  Future<UserModel> updateProfile({
    required String username,
    String? avatar,
    String? bio,
    bool? isPrivate,
  }) async {
    final res = await _api.post(
      ApiEndpoints.updateProfile,
      body: {
        'username': username,
        if (avatar != null) 'avatar': avatar,
        if (bio != null) 'bio': bio,
        if (isPrivate != null) 'isPrivate': isPrivate,
      },
    );

    return UserModel.fromJson(jsonDecode(res.data));
  }

  Future<List<UserModel>> getFollowers(String userId) async {
    final res = await _api.get(ApiEndpoints.followers(userId));
    return (jsonDecode(res.data) as List)
        .map((e) => UserModel.fromJson(e))
        .toList();
  }

  Future<List<UserModel>> getFollowing(String userId) async {
    final res = await _api.get(ApiEndpoints.following(userId));
    return (jsonDecode(res.data) as List)
        .map((e) => UserModel.fromJson(e))
        .toList();
  }

  Future<List<PostModel>> getUserPosts(String userId) async {
    final res = await _api.get(
      '${ApiEndpoints.posts}?user=$userId',
    );

    return (jsonDecode(res.data) as List)
        .map((e) => PostModel.fromJson(e))
        .toList();
  }

  Future<List<ReelModel>> getUserReels(String userId) async {
    final res = await _api.get(
      '${ApiEndpoints.reels}?user=$userId',
    );

    return (jsonDecode(res.data) as List)
        .map((e) => ReelModel.fromJson(e))
        .toList();
  }

  Future<void> toggleFollow(String userId) async {
    await _api.post(ApiEndpoints.toggleFollow(userId));
  }
}
