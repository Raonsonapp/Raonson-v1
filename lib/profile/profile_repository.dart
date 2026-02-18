import 'dart:convert';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../models/reel_model.dart';

class ProfileRepository {
  final ApiClient _api = ApiClient.instance;

  /// GET PROFILE
  Future<UserModel> getProfile(String userId) async {
    final res = await _api.getRequest(
      ApiEndpoints.userProfile(userId),
    );

    return UserModel.fromJson(jsonDecode(res.body));
  }

  /// UPDATE PROFILE
  Future<UserModel> updateProfile({
    required String username,
    String? avatar,
    String? bio,
    bool? isPrivate,
  }) async {
    final res = await _api.putRequest(
      ApiEndpoints.updateProfile,
      body: {
        'username': username,
        if (avatar != null) 'avatar': avatar,
        if (bio != null) 'bio': bio,
        if (isPrivate != null) 'isPrivate': isPrivate,
      },
    );

    return UserModel.fromJson(jsonDecode(res.body));
  }

  /// FOLLOWERS
  Future<List<UserModel>> getFollowers(String userId) async {
    final res = await _api.getRequest(
      ApiEndpoints.followers(userId),
    );

    final List list = jsonDecode(res.body);
    return list.map((e) => UserModel.fromJson(e)).toList();
  }

  /// FOLLOWING
  Future<List<UserModel>> getFollowing(String userId) async {
    final res = await _api.getRequest(
      ApiEndpoints.following(userId),
    );

    final List list = jsonDecode(res.body);
    return list.map((e) => UserModel.fromJson(e)).toList();
  }

  /// USER POSTS
  Future<List<PostModel>> getUserPosts(String userId) async {
    final res = await _api.getRequest(
      '${ApiEndpoints.posts}?user=$userId',
    );

    final List list = jsonDecode(res.body);
    return list.map((e) => PostModel.fromJson(e)).toList();
  }

  /// USER REELS
  Future<List<ReelModel>> getUserReels(String userId) async {
    final res = await _api.getRequest(
      '${ApiEndpoints.reels}?user=$userId',
    );

    final List list = jsonDecode(res.body);
    return list.map((e) => ReelModel.fromJson(e)).toList();
  }

  /// FOLLOW / UNFOLLOW
  Future<void> toggleFollow(String userId) async {
    await _api.postRequest(
      ApiEndpoints.toggleFollow(userId),
    );
  }
}
