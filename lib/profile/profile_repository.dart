import 'dart:convert';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/user_model.dart';

class ProfileRepository {
  /// =========================
  /// GET PROFILE BY USER ID
  /// =========================
  Future<UserModel> getProfile(String userId) async {
    final response = await ApiClient.get(
      ApiEndpoints.userProfile(userId),
    );

    final data = jsonDecode(response.body);
    return UserModel.fromJson(data);
  }

  /// =========================
  /// UPDATE PROFILE
  /// =========================
  Future<UserModel> updateProfile({
    required String username,
    String? avatar,
    String? bio,
    bool? isPrivate,
  }) async {
    final response = await ApiClient.put(
      ApiEndpoints.updateProfile,
      body: {
        'username': username,
        if (avatar != null) 'avatar': avatar,
        if (bio != null) 'bio': bio,
        if (isPrivate != null) 'isPrivate': isPrivate,
      },
    );

    final data = jsonDecode(response.body);
    return UserModel.fromJson(data);
  }

  /// =========================
  /// GET FOLLOWERS
  /// =========================
  Future<List<UserModel>> getFollowers(String userId) async {
    final response = await ApiClient.get(
      ApiEndpoints.followers(userId),
    );

    final List list = jsonDecode(response.body);
    return list.map((e) => UserModel.fromJson(e)).toList();
  }

  /// =========================
  /// GET FOLLOWING
  /// =========================
  Future<List<UserModel>> getFollowing(String userId) async {
    final response = await ApiClient.get(
      ApiEndpoints.following(userId),
    );

    final List list = jsonDecode(response.body);
    return list.map((e) => UserModel.fromJson(e)).toList();
  }

  /// =========================
  /// FOLLOW / UNFOLLOW USER
  /// =========================
  Future<void> toggleFollow(String userId) async {
    await ApiClient.post(
      ApiEndpoints.toggleFollow(userId),
    );
  }

  /// =========================
  /// ACCEPT FOLLOW REQUEST
  /// =========================
  Future<void> acceptFollowRequest(String userId) async {
    await ApiClient.post(
      ApiEndpoints.acceptFollow(userId),
    );
  }

  /// =========================
  /// DECLINE FOLLOW REQUEST
  /// =========================
  Future<void> declineFollowRequest(String userId) async {
    await ApiClient.post(
      ApiEndpoints.declineFollow(userId),
    );
  }
}
