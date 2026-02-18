import 'dart:convert';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../models/reel_model.dart';

class ProfileRepository {
  /// GET PROFILE
  Future<UserModel> getProfile(String userId) async {
    final response =
        await ApiClient.get(ApiEndpoints.userProfile(userId));

    final Map<String, dynamic> data = jsonDecode(response.body);
    return UserModel.fromJson(data);
  }

  /// UPDATE PROFILE
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

    final Map<String, dynamic> data = jsonDecode(response.body);
    return UserModel.fromJson(data);
  }

  /// USER POSTS
  Future<List<PostModel>> getUserPosts(String userId) async {
    final response =
        await ApiClient.get('${ApiEndpoints.posts}?user=$userId');

    final List list = jsonDecode(response.body) as List;
    return list.map((e) => PostModel.fromJson(e)).toList();
  }

  /// USER REELS
  Future<List<ReelModel>> getUserReels(String userId) async {
    final response =
        await ApiClient.get('${ApiEndpoints.reels}?user=$userId');

    final List list = jsonDecode(response.body) as List;
    return list.map((e) => ReelModel.fromJson(e)).toList();
  }

  /// FOLLOW
  Future<void> follow(String userId) async {
    await ApiClient.post(ApiEndpoints.toggleFollow(userId));
  }

  /// UNFOLLOW
  Future<void> unfollow(String userId) async {
    await ApiClient.post(ApiEndpoints.toggleFollow(userId));
  }
}
