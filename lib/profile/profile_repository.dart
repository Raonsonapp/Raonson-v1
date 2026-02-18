import 'dart:convert';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/user_model.dart';
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
  }) async {
    await _api.post(
      ApiEndpoints.updateProfile,
      body: {
        'username': username,
        'bio': bio,
      },
    );
  }

  // ================= FOLLOW =================

  Future<void> follow(String userId) {
    return _api.post('/follow/$userId');
  }

  Future<void> unfollow(String userId) {
    return _api.post('/unfollow/$userId');
  }

  // ================= REELS =================

  Future<List<ReelModel>> getUserReels(String userId) async {
    final res = await _api.get('/users/$userId/reels');
    final List list = jsonDecode(res.body);
    return list.map((e) => ReelModel.fromJson(e)).toList();
  }
}
