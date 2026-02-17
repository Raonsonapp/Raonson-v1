import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/user_model.dart';

class ProfileRepository {
  final ApiClient _api = ApiClient.instance;

  /// =========================
  /// GET PROFILE BY USER ID
  /// =========================
  Future<UserModel> getProfile(String userId) async {
    final response = await _api.get(
      ApiEndpoints.userProfile(userId),
    );

    return UserModel.fromJson(response.data);
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
    final response = await _api.put(
      ApiEndpoints.updateProfile,
      data: {
        'username': username,
        if (avatar != null) 'avatar': avatar,
        if (bio != null) 'bio': bio,
        if (isPrivate != null) 'isPrivate': isPrivate,
      },
    );

    return UserModel.fromJson(response.data);
  }

  /// =========================
  /// GET FOLLOWERS
  /// =========================
  Future<List<UserModel>> getFollowers(String userId) async {
    final response = await _api.get(
      ApiEndpoints.followers(userId),
    );

    final List list = response.data as List;
    return list.map((e) => UserModel.fromJson(e)).toList();
  }

  /// =========================
  /// GET FOLLOWING
  /// =========================
  Future<List<UserModel>> getFollowing(String userId) async {
    final response = await _api.get(
      ApiEndpoints.following(userId),
    );

    final List list = response.data as List;
    return list.map((e) => UserModel.fromJson(e)).toList();
  }

  /// =========================
  /// FOLLOW / UNFOLLOW USER
  /// =========================
  Future<void> toggleFollow(String userId) async {
    await _api.post(
      ApiEndpoints.toggleFollow(userId),
    );
  }

  /// =========================
  /// ACCEPT FOLLOW REQUEST
  /// =========================
  Future<void> acceptFollowRequest(String userId) async {
    await _api.post(
      ApiEndpoints.acceptFollow(userId),
    );
  }

  /// =========================
  /// DECLINE FOLLOW REQUEST
  /// =========================
  Future<void> declineFollowRequest(String userId) async {
    await _api.post(
      ApiEndpoints.declineFollow(userId),
    );
  }
}
