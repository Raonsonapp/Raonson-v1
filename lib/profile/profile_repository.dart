import 'dart:convert';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';

class ProfileRepository {
  final ApiClient _api;

  ProfileRepository(this._api);

  // ================= PROFILE =================

  Future<UserModel> getProfile(String userId) async {
    final res = await _api.getRequest(
      ApiEndpoints.userProfile(userId),
    );

    return UserModel.fromJson(
      jsonDecode(res.body),
    );
  }

  Future<List<PostModel>> getUserPosts(String userId) async {
    final res = await _api.getRequest(
      '${ApiEndpoints.userProfile(userId)}/posts',
    );

    final List list = jsonDecode(res.body);
    return list.map((e) => PostModel.fromJson(e)).toList();
  }

  // ================= FOLLOW =================

  Future<void> follow(String userId) async {
    await _api.postRequest(
      ApiEndpoints.follow(userId),
    );
  }

  Future<void> unfollow(String userId) async {
    await _api.postRequest(
      ApiEndpoints.unfollow(userId),
    );
  }

  // ================= FOLLOW LIST =================

  Future<List<UserModel>> getFollowers(String userId) async {
    final res = await _api.getRequest(
      ApiEndpoints.followers(userId),
    );

    final List list = jsonDecode(res.body);
    return list.map((e) => UserModel.fromJson(e)).toList();
  }

  Future<List<UserModel>> getFollowing(String userId) async {
    final res = await _api.getRequest(
      ApiEndpoints.following(userId),
    );

    final List list = jsonDecode(res.body);
    return list.map((e) => UserModel.fromJson(e)).toList();
  }
}
